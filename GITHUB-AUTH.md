# GitHub 认证配置指南

## 方案1: 使用 Personal Access Token (推荐)

### 步骤1: 生成 Token
1. 访问: https://github.com/settings/tokens
2. 点击 "Generate new token (classic)"
3. 勾选权限:
   - ✅ repo (所有权限)
   - ✅ workflow
4. 点击生成,复制Token (ghp_xxxxx...)

### 步骤2: 在终端配置
```bash
cd /root/NexusHive

# 使用Token推送
git push https://ghp_你的Token@github.com/Zoumachuan/NexusHive.git main

# 或者配置Git保存认证
git config credential.helper store
git push origin main
# 输入用户名: Zoumachuan
# 输入密码: ghp_你的Token
```

---

## 方案2: 使用 SSH Key (更安全)

### 步骤1: 生成SSH密钥
```bash
ssh-keygen -t ed25519 -C "prof_zhen@126.com"
# 一路回车(不设置密码)

# 查看公钥
cat ~/.ssh/id_ed25519.pub
```

### 步骤2: 添加到GitHub
1. 复制上面的公钥内容
2. 访问: https://github.com/settings/keys
3. 点击 "New SSH key"
4. 粘贴公钥并保存

### 步骤3: 修改远程地址
```bash
cd /root/NexusHive
git remote set-url origin git@github.com:Zoumachuan/NexusHive.git
git push -u origin main
```

---

## 快速推送(临时方案)

如果你现在就想推送,最快的方法:

```bash
# 1. 去GitHub生成Token: https://github.com/settings/tokens
# 2. 回到终端执行:
cd /root/NexusHive
git push https://你的Token@github.com/Zoumachuan/NexusHive.git main
```

推送成功后,脚本地址就是:
```
https://raw.githubusercontent.com/Zoumachuan/NexusHive/main/deploy-to-new-server.sh
```
