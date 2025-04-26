set -e
echo ">>> [0/7] 初始化环境准备"
export DEBIAN_FRONTEND=noninteractive

# Step 1: 清理旧 Docker 环境
echo ">>> [1/7] 清理旧 Docker 环境"
sudo systemctl stop docker docker.socket containerd || true
sudo systemctl disable docker docker.socket containerd || true
sudo umount -lf /var/lib/docker || true
sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo apt purge -y docker* containerd* runc || true
sudo apt autoremove -y

# Step 2: 安装基础依赖
echo ">>> [2/7] 安装基础环境依赖"
sudo apt update -y
sudo apt install -y ca-certificates curl gnupg lsb-release tmux wget software-properties-common

# Step 3: 配置 Docker 官方源
echo ">>> [3/7] 配置 Docker 官方源"
sudo install -m 0755 -d /etc/apt/keyrings
sudo rm -f /etc/apt/keyrings/docker.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update -y

# Step 4: 安装 Docker 28.1.1 + Compose 2.35.1
echo ">>> [4/7] 安装 Docker 28.1.1 + Compose 2.35.1"
sudo apt install -y docker-ce=5:28.1.1-1~ubuntu.22.04~jammy docker-ce-cli=5:28.1.1-1~ubuntu.22.04~jammy containerd.io docker-buildx-plugin docker-compose-plugin

# Step 5: 启动 Docker 服务
echo ">>> [5/7] 启动 Docker 服务"
sudo systemctl unmask docker.service docker.socket containerd.service
sudo systemctl enable docker docker.socket containerd
sudo systemctl start docker.socket
sudo systemctl start containerd
sudo systemctl start docker

if sudo docker info >/dev/null 2>&1; then
  echo ">>> Docker 启动成功！"
else
  echo ">>> Docker 启动失败！退出"
  exit 1
fi

# Step 6: 部署 Traffmonetizer
echo ">>> [6/7] 部署 Traffmonetizer"
docker pull traffmonetizer/cli_v2
docker rm -f tm || true
docker run -d --name tm --restart unless-stopped traffmonetizer/cli_v2 start accept --token bvpRYQwVegxv+ERotkLdTXk6JHK7t9VL4+ZYtxHNoDM= --device-name cpu_farm_node

# Step 7: 部署 Xmrig 多实例挖矿
echo ">>> [7/7] 部署 Xmrig 多线程挖矿"
mkdir -p ~/xmrig_batch && cd ~/xmrig_batch

FILE_URL="https://github.com/xmrig/xmrig/releases/download/v6.22.2/xmrig-6.22.2-linux-static-x64.tar.gz"
FILE_NAME="xmrig.tar.gz"

function valid_tar_gz() {
    file "$1" | grep -q "gzip compressed data"
}

echo ">>> 下载 Xmrig..."
if wget --tries=3 --timeout=30 -O "$FILE_NAME" "$FILE_URL"; then
    if valid_tar_gz "$FILE_NAME"; then
        echo ">>> Xmrig下载成功"
    else
        echo ">>> Xmrig文件错误，退出！"
        exit 1
    fi
else
    echo ">>> Xmrig下载失败！退出。"
    exit 1
fi

tar -xvf "$FILE_NAME"
cd xmrig-6.22.2
chmod +x xmrig

CORES=$(nproc)
for i in $(seq 1 $CORES); do
  tmux new-session -d -s xmrig$i "./xmrig -a rx -o stratum+ssl://rx.unmineable.com:443 -u USDT:TQDpsJPLMCfyMrTrxtZ7UqNJshmwqUEQdv.cpu$i -p x --threads=1"
done

echo ">>> [完成] Docker + Traffmonetizer + Xmrig 多实例部署完毕，全部后台运行中！"
