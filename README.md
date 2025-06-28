# Sepolia RPC 节点搭建 (Geth + Prysm)

## 🙂 更新 VPS 

```bash

sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y && sudo apt install git -y

```
## 🚀 一键部署

执行如下命令

```bash
bash <(curl -s https://raw.githubusercontent.com/MeG0302/Sepolia-node-deployment-script/main/setup.sh)
```

看到如下截图就是对了:

![Screenshot 2025-05-19 020345](https://github.com/user-attachments/assets/4763da84-e823-4dec-a142-17866b99b1b5)

> 💡 按 `CTRL + C` 退出日志.

## 🕒 同步节点

⏳ 部署完成后需要 2–5 小时来同步数据 
---

## ✅ 检查同步是否完成

### ➡️ 执行层 (Geth)

使用命令:

```bash
curl -X POST -H "Content-Type: application/json" \
--data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
http://localhost:8545
```

- ✅ 同步完成会显示

```json
{"jsonrpc":"2.0","id":1,"result":false}
```

- 🚫 还在同步会显示

```json
{
  "jsonrpc":"2.0",
  "id":1,
  "result":{
    "startingBlock":"0x0",
    "currentBlock":"0x1a2b3c",
    "highestBlock":"0x1a2b4d"
  }
}
```

---

### ➡️ 共识层节点 (Prysm)

检查同步状态:

```bash
curl http://localhost:3500/eth/v1/node/syncing
```

- ✅ 同步完成的话会显示

```json
{
  "data": {
    "head_slot": "12345",
    "sync_distance": "0",
    "is_syncing": false
  }
}
```

- 🚫 正在同步会显示

```json
{
  "data": {
    "head_slot": "12345",
    "sync_distance": "100",
    "is_syncing": true
  }
}
```




## 🌐 获取RPC地址

### ⚙️ 执行层(Geth)
你的地址就是

  `http://你的服务器IP:8545` 比如 `http://203.0.113.5:8545`


---

### 🔗 共识层 (Prysm)


你的地址就是 
  `http://localhost:3500`

添加防火墙规则
在你的RPC节点上使用：
`sudo ufw allow from "你的Aztec节点IP" to any port 8545 proto tcp`


---
