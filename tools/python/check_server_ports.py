import socket

HOST = "178.156.202.89"
PORTS = [8043, 9043, 9123]

print(f"Checking connection to {HOST}...")

for port in PORTS:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(3)
    result = sock.connect_ex((HOST, port))
    if result == 0:
        print(f"✅ Port {port} is OPEN")
    else:
        print(f"❌ Port {port} is CLOSED (Code: {result})")
    sock.close()
