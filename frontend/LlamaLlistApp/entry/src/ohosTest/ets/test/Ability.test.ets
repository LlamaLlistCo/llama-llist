import { hilog } from '@kit.PerformanceAnalysisKit';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';

type TodoStatus = 'pending' | 'completed' | 'delayed';
type TodoPriority = 'important_urgent' | 'important_not_urgent' | 'not_important_urgent' | 'not_important_not_urgent';

function normalizeSummary(summary: string): string {
  const text = (summary || '').trim();
  if (text.length > 300) {
    return text.substring(0, 300);
  }
  return text;
}

function todoMatchesFilter(status: TodoStatus, priority: TodoPriority, statusFilter: TodoStatus | 'all', priorityFilter: TodoPriority | 'all'): boolean {
  const statusMatched = statusFilter === 'all' || status === statusFilter;
  const priorityMatched = priorityFilter === 'all' || priority === priorityFilter;
  return statusMatched && priorityMatched;
}

export default function abilityTest() {
  describe('ActsAbilityTest', () => {
    beforeAll(() => {})
    beforeEach(() => {})
    afterEach(() => {})
    afterAll(() => {})

    it('equivalencePartition_todoFilter', 0, () => {
      hilog.info(0x0000, 'testTag', '%{public}s', 'equivalence partition begin');

      expect(todoMatchesFilter('pending', 'important_urgent', 'all', 'all')).assertTrue();
      expect(todoMatchesFilter('pending', 'important_urgent', 'pending', 'all')).assertTrue();
      expect(todoMatchesFilter('pending', 'important_urgent', 'completed', 'all')).assertFalse();

      expect(todoMatchesFilter('completed', 'important_not_urgent', 'all', 'important_not_urgent')).assertTrue();
      expect(todoMatchesFilter('completed', 'important_not_urgent', 'all', 'not_important_urgent')).assertFalse();
    })

    it('boundaryValue_summaryLength', 0, () => {
      hilog.info(0x0000, 'testTag', '%{public}s', 'boundary value begin');

      const s299 = 'a'.repeat(299);
      const s300 = 'a'.repeat(300);
      const s301 = 'a'.repeat(301);

      expect(normalizeSummary(s299).length).assertEqual(299);
      expect(normalizeSummary(s300).length).assertEqual(300);
      expect(normalizeSummary(s301).length).assertEqual(300);
    })
  })
}
