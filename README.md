# read-paper — 论文精读拆解

精读并拆解学术论文（以 PDF 为主），**自动适配论文类型**（理论证明 / 实验方法 / 综述 / 系统）。把一篇或多篇论文整理成一套详细、可教学的分析条目（每个承重结果 / 方法 / 实验一个 markdown 文件），外加一份导航总览。

## 安装

通过 [`npx skills`](https://skills.sh) 一键安装（registry 就是 GitHub 本身）：

```bash
# 装到当前项目（.claude/skills/）
npx skills add LuoHaomin/read-paper

# 装到全局，并指定 Claude Code
npx skills add LuoHaomin/read-paper -g -a claude-code
```

兼容 Claude Code / Cursor / Codex / Copilot 等 70+ agent。

## 这是什么

每个条目做到：定位清晰、大白话直觉、分步推导 / 实验解读、点出非平凡之处、并焊进全局。公式用规范 LaTeX，关系图用 mermaid，几何图用内联 SVG。

结构标准全部写死在 `SKILL.md` 与 `reference/` 下的模板里——照着做即可。每个模板内嵌自包含的范例条目当质量锚点。

触发词：读论文 / 解读 / 拆解 / 整理 / 分析 / 精读 / summarize / analyze / digest。

## 仓库结构

```
read-paper/
├── SKILL.md                # 核心指令、论文类型识别、质量基线
├── extract.sh              # PDF 文本抽取驱动脚本（自定位）
├── reference/
│   ├── entry-theory.md     # 理论类条目模板 + 范例
│   ├── entry-method.md     # 实验方法类条目模板 + 范例
│   └── overview-template.md
├── README.md
└── LICENSE
```

> 本 skill 是**文档分析** skill（无 app、无截图）。"验证"标准 = 拿一篇 PDF 跑通全流程，产出符合质量基线的条目。`example/` 里就是一次真实运行的产物，供参考。

## 许可

MIT —— 自由使用、修改、分发。
