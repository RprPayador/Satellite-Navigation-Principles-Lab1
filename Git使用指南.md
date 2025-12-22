# Git 版本控制使用指南

## 三个区域

```
工作区 (Working Directory)     ← 你编辑的文件
    ↓ git add
暂存区 (Staging Area)          ← 准备提交的快照
    ↓ git commit
本地仓库 (Repository)          ← 保存所有历史版本
```

## 常用命令速查

| 操作 | 命令 | 说明 |
|------|------|------|
| 初始化 | `git init` | 创建仓库（只需一次） |
| 查看状态 | `git status` | 查看哪些文件被修改 |
| 添加到暂存区 | `git add .` | 添加所有修改 |
| 提交 | `git commit -m "说明"` | 保存一个版本 |
| 查看历史 | `git log --oneline` | 查看所有提交记录 |
| 回滚 | `git reset --hard <id>` | 回到某个版本 |

## 关键要点

1. **`git add` 是快照**：只保存执行那一刻的文件状态，之后的修改不会自动进入暂存区

2. **勤 commit**：每次有意义的修改都 commit，不要只 add 不 commit

3. **恢复暂存区内容**：`git checkout -- 文件名`

## 日常工作流程

```bash
# 1. 修改代码
# 2. 保存版本
git add .
git commit -m "完成XX功能"

# 3. 继续修改...
# 4. 再次保存
git add .
git commit -m "修复XX问题"

# 5. 需要回滚时
git log --oneline        # 查看历史，找到要回滚的版本ID
git reset --hard abc123  # 回滚
```
