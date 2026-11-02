#!/usr/bin/env bash
# A change another container writes to the shared checkout is built and served without
# restarting the container, a build that fails leaves the running build up, and the watcher
# stops with its application. This does not substitute for cross-node NFS acceptance.
set -euo pipefail
volume="workspace-java-reload-$$"
server="workspace-java-reload-server-$$"
docker volume create "$volume" >/dev/null
cleanup() { docker rm -f "$server" >/dev/null 2>&1 || true; docker volume rm "$volume" >/dev/null; }
trap cleanup EXIT
image="${IMAGE:?Set IMAGE to the candidate Java development image}"
# Run as the image's own user: the checkout belongs to it in a workspace.
write() { docker run --rm -i --network none --entrypoint sh -v "$volume:/fixture" "$image" -ec "$1"; }
docker run --rm --user 0 --entrypoint sh -v "$volume:/fixture" "$image" -ec 'chown "$(id -u wodby):$(id -g wodby)" /fixture'
docker run --rm -i --entrypoint sh -v "$volume:/fixture" -v "$PWD/app:/app:ro" "$image" -ec 'cp -r /app/. /fixture/; cd /fixture; git init -q'
write '
mkdir -p /fixture/src/main/resources
printf "resource-before" > /fixture/src/main/resources/static.txt
cat > /fixture/src/main/java/test/Main.java <<JAVA
package test;

import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

public class Main {
    public static void main(String[] args) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);
        server.createContext("/", exchange -> {
            byte[] body = "before-edit".getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(200, body.length);
            exchange.getResponseBody().write(body);
            exchange.close();
        });
        server.createContext("/static", exchange -> {
            byte[] body = Main.class.getResourceAsStream("/static.txt").readAllBytes();
            exchange.sendResponseHeaders(200, body.length);
            exchange.getResponseBody().write(body);
            exchange.close();
        });
        server.createContext("/exit", exchange -> System.exit(7));
        server.start();
    }
}
JAVA
'
start() { docker run -d --name "$server" --entrypoint /usr/local/bin/workspace-java -e APP_ROOT=/fixture -e WORKSPACE_POLL_INTERVAL=500 "$@" -v "$volume:/fixture" "$image" start >/dev/null; }
get() { docker exec "$server" wget -qO- "http://127.0.0.1:8080$1" 2>/dev/null; }
# Waits until a path answers with the wanted text; prints the server's log when it never does.
serves() {
 for _ in $(seq 1 180); do
  if [ "$(get "$1" || true)" = "$2" ]; then return 0; fi
  sleep 1
 done
 echo "$1 never answered $2" >&2; docker logs "$server" >&2; exit 1
}
start
serves / before-edit
serves /static resource-before
first=$(docker inspect -f '{{.State.StartedAt}}' "$server")

write 'sed -i "s/before-edit/after-edit/" /fixture/src/main/java/test/Main.java'
serves / after-edit
echo 'java: a change to the source was built and served'

# A build that fails must not take the running build down.
write 'printf "\nclass Broken {\n" >> /fixture/src/main/java/test/Main.java'
for _ in $(seq 1 120); do
 if docker logs "$server" 2>&1 | grep -q 'the build failed; the previous build keeps running'; then break; fi
 sleep 1
done
docker logs "$server" 2>&1 | grep -q 'the build failed; the previous build keeps running'
serves / after-edit
echo 'java: a failed build left the running build up'

# Fixed again, with a change to a resource the build packages.
write 'sed -i "/^class Broken {$/d" /fixture/src/main/java/test/Main.java; printf "resource-after" > /fixture/src/main/resources/static.txt'
serves /static resource-after
echo 'java: a change to a resource was built and served'

# All of that happened in one container.
test "$(docker inspect -f '{{.State.StartedAt}} {{.RestartCount}}' "$server")" = "$first 0"

# Build output and dependency storage are not watched: nothing is built while nothing changes.
builds=$(docker logs "$server" 2>&1 | grep -c 'the checkout changed; building')
sleep 5
test "$(docker logs "$server" 2>&1 | grep -c 'the checkout changed; building')" = "$builds"
echo 'java: build output did not trigger builds'

# The watcher ends with an application that exits by itself, keeping its exit code.
docker exec "$server" wget -qO- http://127.0.0.1:8080/exit >/dev/null 2>&1 || true
docker wait "$server" | grep -qx 7
echo 'java: the container ended with the application'
