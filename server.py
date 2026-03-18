import socket
import json

SERVER_IP = "0.0.0.0"
SERVER_PORT = 9999

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((SERVER_IP, SERVER_PORT))
sock.setblocking(False)

clients = set()
print(f"Tank Multiplayer UDP Server started on port {SERVER_PORT}...")

try:
    while True:
        try:
            data, addr = sock.recvfrom(2048)
            if addr not in clients:
                clients.add(addr)
                print(f"New player joined from {addr}")
            
            # Relay the JSON message to everyone else
            message = json.loads(data.decode('utf-8'))
            for c in list(clients):
                if c != addr:
                    try:
                        sock.sendto(data, c)
                    except Exception:
                        clients.remove(c)
        except BlockingIOError:
            pass
        except ConnectionResetError:
            pass
        except Exception as e:
            pass

except KeyboardInterrupt:
    print("\nServer stopping...")
finally:
    sock.close()
