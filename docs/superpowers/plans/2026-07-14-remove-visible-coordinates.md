# 删除界面坐标展示实施计划

> **执行要求：** 必须使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans`，逐项执行本计划。所有步骤使用复选框跟踪。

**目标：** 删除车站区间编辑器中面向用户展示的车站坐标，同时保留所有内部地图坐标和现有功能。

**实现方式：** 在现有地图按钮编辑工具旁增加一个纯标签函数，通过 Node 测试锁定输出格式，并在 `MapView.vue` 中复用。后端、数据库、API 和坐标类型均不修改。

**技术栈：** Vue 3、TypeScript、Element Plus、Node.js 测试运行器

---

### 任务一：区间车站选项只显示车站名称

**涉及文件：**
- 修改：`frontend/src/utils/markerEdit.test.mjs`
- 修改：`frontend/src/utils/markerEdit.ts`
- 修改：`frontend/src/views/MapView.vue`

- [ ] **步骤 1：先编写失败测试**

在 `markerEdit.test.mjs` 中引入新函数并添加测试：

```js
import { intervalMarkerLabel, markerEditStationOptions, markerTypeForStation } from './markerEdit.ts'

test('区间车站选项只显示车站名称', () => {
  assert.equal(intervalMarkerLabel({ station: { name: '大牛店' }, x: 467.9, y: 285.6 }), '大牛店')
})
```

- [ ] **步骤 2：运行测试并确认其按预期失败**

执行：

```bash
cd frontend
node --test src/utils/markerEdit.test.mjs
```

预期结果：测试失败，原因是 `intervalMarkerLabel` 尚未导出。

- [ ] **步骤 3：实现最小改动**

在 `frontend/src/utils/markerEdit.ts` 中添加：

```ts
export function intervalMarkerLabel(marker: { station: Pick<Station, 'name'> }) {
  return marker.station.name
}
```

在 `MapView.vue` 中引入该函数，并替换原先包含坐标的标签格式：

```ts
import { intervalMarkerLabel, markerEditStationOptions, markerTypeForStation } from '../utils/markerEdit'

function markerOptionLabel(marker: MapMarker) {
  return intervalMarkerLabel(marker)
}
```

- [ ] **步骤 4：运行完整自动化验证**

执行：

```bash
cd frontend
node --test src/**/*.test.mjs
npm run build
```

预期结果：全部测试通过，Vite 构建成功退出。

- [ ] **步骤 5：提交功能代码**

```bash
git add frontend/src/utils/markerEdit.test.mjs frontend/src/utils/markerEdit.ts frontend/src/views/MapView.vue
git commit -m "Remove coordinates from interval labels"
```

### 任务二：合并并进行本地验证

- [ ] 将功能分支快进合并回本地 `main`，不修改或删除其他并行 worktree。
- [ ] 重新构建本地 Docker 应用，测试地址为 `http://127.0.0.1:8012/`。
- [ ] 打开 `/map`，进入“编辑布局”并选中“大牛店—梅家庄”区间；确认车站 A、车站 B 下拉框只显示车站名称，右侧区间信息仍为只读，地图位置及区间悬浮信息保持正常。
- [ ] 执行 `docker compose ps`、HTTP 健康检查和 `git diff --check`；除非用户明确要求，否则本地 `main` 不推送远程、不部署生产环境。
