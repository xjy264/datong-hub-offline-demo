package cn.datong.map.station;

public final class StationRules {
    private static final String CHILD_REJECTED = "第三级目录不能添加下级";
    private static final String NON_EMPTY = "非空目录不能删除";

    private StationRules() {
    }

    public static void ensureCanAddChild(int parentDepth) {
        if (parentDepth >= 3) {
            throw new IllegalArgumentException(CHILD_REJECTED);
        }
    }

    public static void ensureFolderEmpty(int childCount, int imageCount) {
        if (childCount > 0 || imageCount > 0) {
            throw new IllegalArgumentException(NON_EMPTY);
        }
    }
}
