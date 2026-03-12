# Git 最小工作流（个人仓库直推 main）

适用仓库：`/home/shino/.config/hypr`

## 0. 本次问题修复结果

- 已从游离 HEAD 修复到 `main`
- 已创建备份分支：`backup-detached-0.0.8`
- 当前状态：`main` 比 `origin/main` 超前 3 个提交
- 现在只差鉴权后执行一次推送

## 1. 日常固定四步（终端）

```bash
git status -sb
git pull --rebase origin main
git add -A
git commit -m "your message"
git push origin main
```

规则：

1. 每次先看 `git status -sb`，确认在 `main`
2. 先 `pull --rebase` 再提交推送，减少冲突
3. 不在分支上（出现 `HEAD (no branch)`）不要继续开发

## 2. IDE 对照操作（通用）

1. `Checkout Branch -> main`
2. `Pull (Rebase)`
3. `Commit`（填写 message）
4. `Push -> origin/main`

## 3. 常见报错处理

### A. `HEAD detached` / `not currently on a branch`

```bash
git switch main
```

如果你在游离状态已经做了提交，先建备份分支再切回：

```bash
git branch backup-<tag> <commit>
git switch main
git cherry-pick <commit>
```

### B. `non-fast-forward`

```bash
git fetch origin
git rebase origin/main
git push origin main
```

### C. `Authentication failed` / `could not read Username`

HTTPS 方式需要 PAT（不是 GitHub 密码）：

```bash
git push -u origin main
```

出现用户名/令牌提示时：

- Username：你的 GitHub 用户名
- Password：填 GitHub PAT

可选：开启凭据缓存（避免每次输入）：

```bash
git config --global credential.helper store
```

## 4. 推送前 10 秒自检

```bash
git status -sb
git branch -vv
```

你应该看到：

- 当前分支是 `main`
- 工作区 clean
- 没有 `HEAD (no branch)`
