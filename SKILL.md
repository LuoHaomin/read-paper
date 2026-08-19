---
name: read-paper
description: 精读并拆解学术论文（以 PDF 为主），自动适配论文类型（理论证明 / 实验方法 / 综述 / 系统）。把一篇或多篇论文整理成一套详细、可教学的分析条目（每个承重结果 / 方法 / 实验一个 markdown 文件）外加一份导航总览：含形式陈述或问题动机、大白话直觉、分步推导或实验解读、非平凡之处、以及它在全局里的角色；公式用规范 LaTeX，关系图用 mermaid、几何图用内联 SVG。当用户要求 读论文 / 解读 / 拆解 / 整理 / 分析 / 精读 / summarize / analyze / digest 一篇或多篇论文、PDF、或要把论文变成学习笔记时使用。
---

# read-paper — 论文精读拆解

把一篇（或多篇）学术论文整理成一套**详细、可教学的分析条目 + 一份导航总览**。本 skill **自动识别论文类型**（理论证明 / 实验方法 / 综述 / 系统），按类型选用对应的拆解模板——不再把所有论文都套进"定理+证明"的模子。

每个条目要做到：定位清晰、有大白话直觉、推导/实验可被逐步追问、点出非平凡之处、并焊进全局。**结构标准全部写死在本文件和 [`reference/`](reference/) 下的模板里——照着做即可。** 每个模板里都内嵌了自包含的范例条目当质量锚点。

> 本 skill 是**文档分析** skill（无 app、无截图）。"验证"标准 = 你真的拿一篇 PDF 跑通全流程，产出符合下文质量基线的条目。
>
> **两条铁律，贯穿全程：**
> 1. **脚本自定位**：驱动脚本 `extract.sh` 就在本 `SKILL.md` 的**同一目录**下——不要假设它装在 `.claude/skills/read-paper/`，先算出本 skill 目录再用。
> 2. **防幻觉优先**：每个公式 / 数字 / 结论都要能挂回原文出处；挂不上就标 `⚠️ 待核`，**绝不编造**。详见 §3。

---

## 0. 前置条件

- **首选：MinerU MCP（`mcp__mineru__parse_documents`）。** 本地 stdio 版（`uvx mineru-open-mcp`）：云端解析、公式直出 LaTeX、**支持本地文件路径**、不占本地算力。带 `MINERU_API_TOKEN` = vlm 高精度（大论文可用，账号每天 1000 页最高优先级额度）；无 token = flash 免费模式（≤20 页 / 10MB）。
- **MCP 没配？主动问用户，别默默降级。** MinerU 的公式识别远好于 pdftotext，值一问：
  1. 检查：本会话有没有 `mcp__mineru__*` 工具，或 `claude mcp list | grep -i mineru`。
  2. 没有 → 问用户：要不要用 MinerU 云端解析（公式质量最好）？有 token 就发来（https://mineru.net/apiManage/docs 的 API 管理页自建）；没有也行，免费 flash 模式 ≤20 页。**用户拒绝就走 pdftotext，不纠缠。**
  3. 拿到 token（或确认免费模式）→ 装到 **user 级**（写 `~/.claude.json`；**绝不装 project 级——token 会进 `.mcp.json` 被提交**）：
     ```bash
     # 依赖 uv/uvx：brew install uv（或 curl -LsSf https://astral.sh/uv/install.sh | sh）
     claude mcp add mineru -s user -e MINERU_API_TOKEN=<token> -- uvx mineru-open-mcp
     ```
  4. **刚装的 MCP 本会话挂载不上**（要重启会话）——别停：当场走 **§1.5 REST 直调** 干活，收尾告诉用户"MCP 已配好，下个会话起工具直接可用"。
- **⚠️ 别用远程 HTTP MCP（`https://mcp.mineru.net/mcp`）。** 它跑在远端、**读不到本地文件路径**（本地文件只能开浏览器手动上传），且 API token 对该域名无效（401 scope forbidden）。本 skill 一律走本地 stdio 版。
- **回退：`pdftotext`（poppler）** —— MinerU 彻底不可用 / 用户拒绝时用。用到时先查 `command -v pdftotext`，**没装就当场帮用户装上**（这是本 skill 唯一本地依赖，装它别犹豫）：
  ```bash
  command -v pdftotext || brew install poppler                    # macOS（无需 sudo）
  command -v pdftotext || sudo apt-get install -y poppler-utils   # Debian/Ubuntu
  ```
  Linux sudo 要密码、agent 代跑不了 → 让用户在输入框敲 `! sudo apt-get install -y poppler-utils`（`!` 前缀在本会话内直接执行，输出回到对话）。装完接着走，别停。

---

## 1. 抽取文本

**首选 MinerU MCP（公式直出 LaTeX，强烈推荐）。** 若 `mcp__mineru__parse_documents` 可用，直接调它——云端 precision/vlm，输出**干净的 LaTeX Markdown**（公式、表格、阅读顺序、双栏都处理好），从根上消除 pdftotext 的 Unicode 残缺体问题。工具不在但用户已给 token（比如刚按 §0 装完）→ 走 §1.5 REST 直调，等效。

- `file_sources` 每项是路径/URL，或 `{"source":"...","pages":"2-3"}`；语言未知省略 `language`（默认 `ch`）；一般别设 `enable_ocr`（服务器自动判）。
- 整篇：`parse_documents(file_sources=["paper.pdf"])`。
- 只要若干页：`parse_documents(file_sources=[{"source":"paper.pdf","pages":"2-3"}])`。
- 要拿图片/大结果落盘：加 `output_dir`，结果（含 `images/`）写到该目录，笔记可 `![](images/fig1.png)` 引用论文原图。
- **MinerU 非零误差**：偶有符号识别错（如把某算符误识成 `\mathsf{1}`），图片区可能输出空行。故读起来可疑的公式按 §3 标 `⚠️ 待核` 即可（不必逐条）。

**回退：`extract.sh` / `pdftotext`（无 MCP 或 MCP 失败时；poppler 没装就先按 §0 当场装上）。** 脚本在本 SKILL.md 同目录，`-layout` 已内置（双栏必须）：

```bash
bash "<skill 目录>/extract.sh" "paper.pdf"      # PDF 旁生成 .txt；疑似扫描件会告警
pdftotext -layout "paper.pdf" "paper.txt"        # 兜底
```

此路径得到的是 **Unicode 残缺体**，公式须按 §3 重建闸**逐条**重建为规范 LaTeX。

> **抽取来源（MinerU Markdown vs pdftotext 文本）决定 §3 重建闸的严格程度**——记住你这次走的是哪条。

---

## 1.5 MinerU REST 直调（MCP 本会话不可用时，curl 照样干活）

刚按 §0 装完 MCP（本会话挂载不上）、或 MCP 挂了但 token 在手 → 直接调 REST API（与 MCP 的 vlm 模式等效，四步全流程实测可用）：

```bash
T=<用户提供过的 token>          # 只放命令行/环境变量，绝不写进笔记或 git 目录
# 1) 申请上传 URL → 拿 batch_id 和一次性上传地址（24h 内有效）
curl -s -X POST https://mineru.net/api/v4/file-urls/batch \
  -H "Authorization: Bearer $T" -H "Content-Type: application/json" \
  -d '{"files":[{"name":"paper.pdf"}],"model_version":"vlm"}'
# 2) PUT 上传本地文件（系统随即自动开解析；此步不要带 Content-Type）
curl -s -X PUT -T paper.pdf "<上一步 file_urls[0]>"
# 3) 每 10s 轮询，state=done 时给 full_zip_url（小文件 ~10s，大论文几分钟）
curl -s "https://mineru.net/api/v4/extract-results/batch/<batch_id>" \
  -H "Authorization: Bearer $T"
# 4) 下载解压：full.md（LaTeX 公式）+ images/（论文原图，笔记可 ![]() 引用）
curl -sL -o out.zip "<full_zip_url>" && unzip -o out.zip -d "<输出目录>/mineru"
```

- 论文有公网 URL（如 arXiv 直链）可省上传：`POST /api/v4/extract/task`，body `{"url":"...","model_version":"vlm"}`，拿 task_id 轮询 `GET /api/v4/extract/task/<task_id>`。
- 结果当 **MinerU 源**走 §3 重建闸。REST 限额：单文件 ≤200MB / 200 页。上传地址是一次性的，签名 24h 过期。

---

## 2. 分诊：判类型 + 拆解计划（核心，决定走哪条路）

**先别急着写。** 读 abstract + Introduction，扫各章节标题，再用 grep 看结构标记，判定论文类型：

| 类型 | 判定信号 | grep 提示 |
|------|---------|----------|
| **理论证明** | 有 Theorem / Lemma / Proposition / Proof；贡献是数学结论 | `grep -nE 'Theorem\|Lemma\|Proposition\|Fact\|Corollary\|Definition\|Proof' paper.md`（或 `.txt`） |
| **实验方法** | 有 Method / Algorithm / Experiments / Datasets / Baselines / Ablation；贡献是方法+实证 | 看章节标题；ML 论文多属此类 |
| **综述** | 标题/摘要含 survey / review / taxonomy / overview；通篇引用分类 | 看章节是否按主题/方法分类 |
| **系统** | 有 System / Architecture / Implementation / Evaluation；贡献是系统设计+评测 | 看是否有架构图、实现细节章节 |

**接着产出"拆解计划"**——这篇要写哪些条目。用**类型无关的"承重单元"**判断：删掉它，论文的论证就断掉/不完整 → 承重，单独成文；平凡辅助项并进引用它的条目里。

- 理论证明：主定理 + 各承重引理/命题。
- 实验方法：核心方法、关键实验、主要结论、主要局限（各自一条）。
- 综述：分类树 + 每个里程碑工作/子方向一条。
- 系统：核心设计/架构、关键实现、评测与结果。

把计划（类型 + 条目清单）简短列出来，再开写。

---

## 3. 防幻觉三闸（写之前先立规矩，比方法更重要）

抽取来源不同，公式的可信度不同：**MinerU Markdown** 的公式已是 LaTeX（偶有符号错），**pdftotext 文本**则是 **Unicode 残缺体**（`Ω`≠`Ω`、`∣`≠`|`、`ρs` 是 $\rho_s$，数字也可能错位）。无论哪种，**照抄或凭记忆补全都是幻觉的主要来源**。过三道闸：

1. **溯源闸** —— 每个公式 / 数字 / 非平凡结论，都要能挂回原文出处：`(p.X)`、`Eq.(N)`、`Table N`、`Figure N`，或一段直接引用。**挂不上就标 `⚠️ 待核：…`，不得当事实写。**
2. **重建闸（按抽取来源分档；从文本重建，不做视觉核对）** ——
   - **源 = MinerU Markdown**（公式已是 LaTeX）：基本直接采信；仅当某公式读起来可疑 / 与上下文矛盾 / 含生僻符号时，标 `⚠️ 待核`，不硬信也不硬改。
   - **源 = pdftotext 文本**（Unicode 残缺体）：对抽取文本 + 上下文**逐条**重建公式，再写成规范 LaTeX。
   - **拿不准的精确形式**（下标/上标、归一化常数、指数项、记号约定）就地标 `⚠️ 待核：需人工比对 p.X`；能从文本确定的整体结构照常写。可疑公式也可换另一抽取器交叉对照（MinerU ↔ pdftotext）。收尾在 README 汇总全部待核点，交人工一次性核对。原则——**有疑虑的细节一律标待核，而非猜测**。
   - **不要用 Read 把 PDF 页当图读来核对公式。** 实测视觉识别质量不佳（甚至不如直接读抽取文本准确），"视觉核对"反而会引入新错误。
3. **不补全闸** —— 论文没有的章节（如局限、未来工作）就写"原文未讨论"。**禁止替作者编造局限、数字或引用。**

收尾**抽查**：每个条目写完，随机回抽取文本核对 2 处公式/数字。

> **金科玉律：宁可标 `⚠️ 待核`，也不编造。** 一个带待核标记的条目远好过一个自信的错误条目。

---

## 3.5 证明标准（理论型）：完整自洽，禁止"见 SM"式跳步

理论型条目的**证明必须完整、自洽、可逐步追问**——读者照着笔记就能一路验算到底，不需要再翻原文或补充材料。

- **不许"见 SM / 见附录 / 证明略"式跳步。** 论文把推导塞进 Supplemental Material 的，要把那段推导**搬进笔记并展开**；若拿不到 SM（只有 URL、无本地文件），就**基于严谨数学自行补全**，并明确标注「**【补推】**」。
- **鼓励比原文更详细。** 论文一句带过的代数变形、省略的中间步、某个等式/不等式为何成立——都补上。目标是让推导"密不透风"，必要时**比原文更详细**。
- **每步标清依据**：用到哪条前置结果 / 恒等式（Duhamel 公式、Jensen、Araki–Lieb、强次可加性……）/ 不等式，方向（≥ 还是 ≤）如何。
- **三色标注，分清来源**：
  - 原文明确写出 → 照引 + 出处 `(p.X)`；
  - 你补的推导 → 标「**【补推】**」，且**必须严谨**（可被复查）；
  - 拿不准 / 推不通 → 标 `⚠️ 待核：需 …`，**绝不硬凑一个"看起来对"的中间步**。
- **这意味着要读 SM / 附录**（若有本地 PDF），不能只读正文就开写证明。

> 与防幻觉不冲突：防幻觉管的是"别把论文没说的东西当成论文说的"；这里管的是"别把该补的推导偷懒跳过"。补推是你自己的推导——标清楚、推严谨即可。

---

## 4. 写条目：按类型路由到对应模板

打开对应模板照着填——结构、构造要点、范例全在里面：

| 论文类型 | 用哪个模板 |
|---------|----------|
| 理论证明 | [`reference/entry-theory.md`](reference/entry-theory.md) |
| 实验方法 / 系统 | [`reference/entry-method.md`](reference/entry-method.md) |
| 综述 | overview 的分类图 + 每个里程碑用 `entry-method.md` 轻量条目 |

无论哪个模板，每个条目共同的骨架：**定位/陈述 → 大白话含义 → 分步推导或实验解读 → 为什么非平凡 → 大图景角色 + 互链**。

### 配图：mermaid 管关系，SVG 管几何

按图类型分治，别一刀切：

| 图的类型 | 用什么 | 例子 |
|---------|------|------|
| 关系 / 依赖链 / 流程 / 分类树（"节点 → 节点 + 带标签箭头"，位置无所谓） | **mermaid** | 引理依赖链、方法→实验→结论结构图 |
| 几何 / 空间 / 模块布局（二维，位置有意义：光锥、区域、架构框图） | **SVG**（内联） | 光锥、同心层、区域划分、系统模块布局 |
| 极简单行示意（`X ──→ Y` 这种） | **ASCII** | 一行箭头、记号对照 |

- **mermaid**：`flowchart TD`，节点 `[文字]`，边 `A -->|"标签"| B`。节点里数学用**纯文本**（`A = Q Λ Qᵀ`），**不要 `$...$`**，分行用 `<br/>`。自动布局省心、可移植性最好——能用 mermaid 就别用 SVG。
- **SVG**：在 .md **正文里裸写** `<svg>…</svg>`。⚠️ **绝对不要包在 ``` 代码块里**——包进代码块只会显示成一坨源码文本，根本不渲染（mermaid 才需要代码块，SVG 正相反，必须裸写）。给 `viewBox`，用 `rect/circle/line/path/text` + `<marker>` 箭头，颜色当标签层级用。下面这段就是**裸写在正文里、会直接渲染**的范例（在这份 SKILL.md 的预览里你能看到它变成一张图）：

  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 120" font-family="sans-serif" font-size="13">
    <defs><marker id="arr" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L8,3 L0,6 Z" fill="#555"/></marker></defs>
    <rect x="10" y="30" width="120" height="60" fill="#eef3fa" stroke="#1f3a5f"/>
    <text x="70" y="64" text-anchor="middle">A</text>
    <line x1="130" y1="60" x2="250" y2="60" stroke="#555" marker-end="url(#arr)"/>
    <rect x="250" y="30" width="120" height="60" fill="#f7e6e6" stroke="#8a1f1f"/>
    <text x="310" y="64" text-anchor="middle">B</text>
  </svg>

  - **渲染**：VS Code 预览 / Typora / Obsidian / 浏览器都直接渲染**裸写的**内联 SVG。
  - **GitHub 不渲染内联 SVG**（安全策略会剥离）。若笔记要上 GitHub：把 SVG 另存为独立 `.svg` 文件，用 `![](fig.svg)` 引用——GitHub 会把它当图渲染，AI 照样能自动写这个文件。
  - SVG 是纯文本，坐标算错让 AI 改个数字即可迭代；但**未渲染时是一堆 XML**，不如 ASCII 可读，所以只在"几何/布局"时用。

---

## 5. 写总览（每篇必出一个 README.md）

**每篇论文都必须产出一份 `README.md`**（放该论文输出文件夹根目录），作为导航中枢：结果/贡献地图 + 骨架图 + 每条一句话定位 + 互链。照 [`reference/overview-template.md`](reference/overview-template.md) 填。

这是把零散条目收束成全局视野的收尾动作——读者从任意条目进来，都能顺着 README 摸清全篇。

---

## 6. 收尾：互链 + Unicode 还原

- **跨文件互链**：条目之间用相对链接焊起来——`见 [Theorem1.md](Theorem1.md) 第 3 步`、`上游是 [LemmaS3.md](LemmaS3.md)`。目标是读完任一文件都能顺着链接摸清全链。
- **Unicode → LaTeX**：抽出来的文本只当"草稿"，最终公式读懂后用规范 LaTeX 重写（`$\rho_s$`、`$|\partial A|$`、`$\leq$`）。不确定的标 `⚠️ 待核`（§3 重建闸）。

---

## 7. 输出结构

每篇论文产出一个**同名文件夹**：

```
<输出目录>/<论文标题>/
  README.md            ← 必出：导航总览（地图 + 骨架图 + 互链）
  Theorem1.md          ← 理论型：主定理
  LemmaS3.md           ← 理论型：承重引理
  method.md            ← 实验型：核心方法
  experiments.md       ← 实验型：关键实验
  ...
```

**默认输出目录 = PDF 所在目录。** 用户给了别的目录就用那个。多篇论文 → 多个文件夹（可选：再加一个顶层 index 罗列各篇）。

---

## 8. 质量基线（自检，全 ✅ 才达标）

**防幻觉（最高优先级）**
- [ ] 关键公式 / 数字 / 结论都**挂了原文出处**（`(p.X)`/`Eq.(N)`/`Table N`），或诚实标 `⚠️ 待核`？
- [ ] 公式来源分档处理：**MinerU 源**可疑即标待核、**pdftotext 源**逐条从文本重建，拿不准一律标 `⚠️ 待核`？（见 §3）
- [ ] 论文没有的内容写了"**原文未讨论**"，没有替作者编造？

**结构**
- [ ] 形式陈述/定位是**纯陈述**，没夹带推导思路？
- [ ] "含义"是**人话**，不是公式的汉字朗读？
- [ ] 推导/实验**分了步**，且每步标了前置结果/出处？
- [ ] （理论型）证明**完整自洽**：无"见 SM/略"式跳步，论文放 SM 的已搬进来或严谨【补推】，拿不准的标 `⚠️ 待核`？（见 §3.5）
- [ ] 有一节专门讲**"为什么非平凡"**？（没有这节，条目就退化成复读）
- [ ] 公式是**规范 LaTeX**，不是 Unicode 残缺体？
- [ ] 至少一张图？**关系用 mermaid，几何用 SVG**（见 §4）——别用 mermaid 画几何图。
- [ ] 讲清了它在**全局**的角色，链向 README 与相关条目？
- [ ] **README.md 已产出**，含地图 + 骨架图 + 每条一句话？

对照对应模板末尾的自包含范例校准"写到什么程度算够"。

---

## 9. Gotchas（实战踩过的坑）

- **`cd` 在工具调用间不保留。** Bash 每次调用都重置工作目录。要么在同一条命令里 `cd`，要么全程用**绝对路径**。
- **脚本路径别写死。** `extract.sh` 在本 SKILL.md 同目录，别假设 `.claude/skills/read-paper/`。拿不准就用 §1 的 `pdftotext -layout` 兜底。
- **双栏论文必须 `-layout`。** `extract.sh` 已带；手敲 `pdftotext` 别漏。
- **Unicode 数学残缺体。** `Ω`→`Ω`、`∣`→`|`、`∶`→`:`、`ρs`→`$\rho_s$`、`≤`→`$\leq$`。只当草稿，最终 LaTeX 自己重写（§3 重建闸）。
- **方向性不等式极易写反。** 凡出现"≥ 还是 ≤"的步骤，都在"为什么非平凡"里把这方向单独讲清；拿不准翻抽取文本核对，仍拿不准就标 `⚠️ 待核`。
- **扫描版 / 纯图片 PDF** 让 `pdftotext` 吐乱码（`extract.sh` 会打疑似扫描告警）。fallback：用 Read 工具按页读 PDF 图片；或先 `ocrmypdf`（本 skill 不内置）。
- **图、表、复杂矩阵**抽不全。别硬还原，用 ASCII/表格重画示意图并标注"见原文 Figure X / Eq.(B4)"。
- **引用 `[22]`、`[42]`** 一般保留引用键即可；只有当某外部 Fact 是承重环节时，才在条目里点名出处。
- **元信息（作者/年份/出处）拿不准就留空或标"未给出"**，绝不编造。

---

## 10. Troubleshooting

| 症状 | 原因 / 修复 |
|------|-----------|
| `mcp__mineru__parse_documents` 不可用 | MCP 没连。`/mcp` 看 `mineru` 是否 connected；没配就按 §0 问用户要 token 并 `claude mcp add mineru -s user -e MINERU_API_TOKEN=<token> -- uvx mineru-open-mcp`。本会话等不及就走 §1.5 REST 直调，再不行 pdftotext 回退。 |
| 远程 `mcp.mineru.net` 连上但本地文件失败 / 带 token 401 | 该远程版读不了本地路径、API token 对该域名无 scope（§0）。换本地 stdio 版（`uvx mineru-open-mcp`）。 |
| MinerU 解析超时 / 失败 | 多半网络或额度。重试一次；仍失败就走 pdftotext 回退，别阻塞。 |
| MinerU 把某符号识别错（如 `\mathsf{1}`） | 正常，非零误差。可疑就标 `⚠️ 待核`；也可用 `pdftotext` 文本交叉对照。 |
| MinerU 图片区输出空行 | 图本身没转文本。要原图就加 `output_dir` 取 `images/`，否则用 SVG/mermaid 重画示意图。 |
| `extract.sh: No such file` | 路径没算对。用 §1 兜底 `pdftotext -layout`，或确认本 skill 目录。 |
| `pdftotext: command not found` | 没装 poppler。当场帮装：macOS `brew install poppler`；Linux `sudo apt-get install -y poppler-utils`（要密码就让用户敲 `! sudo apt-get install -y poppler-utils`）。装完重跑。 |
| 抽出文本整段乱码 / 词数极低 | 大概率扫描版（`extract.sh` 会告警）。优先让 MinerU 处理（云端 OCR）；否则用 Read 按页读 PDF 图，或先 `ocrmypdf`。 |
| 双栏段落顺序错乱 | 没带 `-layout`。用 `extract.sh`（已带）或 `pdftotext -layout`；MinerU 则自动处理双栏。 |
| 某公式怎么都看不懂 | 别硬猜：标 `⚠️ 待核：需人工比对 p.X`，或换抽取器交叉对照（MinerU ↔ pdftotext）。 |
| 理论型 grep 列不出结果清单 | 结果标题不在行首或用了缩写。放宽：`grep -niE 'theorem\|lemma\|proposition\|fact\|corollar'`。 |
| 实验型论文没有 Theorem | 正常。走 `entry-method.md`，按"核心方法/关键实验/结论/局限"拆。 |

---

## 11. 一句话工作流

```
MinerU MCP: parse_documents(paper.pdf)   # 1. 取文本（首选 MinerU→干净 LaTeX；MCP 缺席但 token 在手→§1.5 直调；否则 extract.sh/pdftotext 兜底）
分诊：判类型 + 拆解计划                    # 2. 理论?实验?综述?系统? → 写哪些承重单元
立防幻觉三闸（按来源分档）                  # 3. 溯源 / 文本重建·待核标记 / 不补全
按类型模板逐个写条目                        # 4. entry-theory.md 或 entry-method.md
写 README.md（导航总览）                   # 5. overview-template.md
公式规范 LaTeX + 互链                      # 6. 收尾
对照质量基线自检（含防幻觉勾选）            # 7. 验收
```
