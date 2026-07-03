package cn.datong.map.station;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StationRulesTest {
    @Test
    void rejectsChildFolderWhenParentIsLevelThree() {
        assertThatThrownBy(() -> StationRules.ensureCanAddChild(3, 0))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("第三级目录或已有图片的目录不能添加下级");
    }

    @Test
    void rejectsChildFolderWhenParentAlreadyHasImages() {
        assertThatThrownBy(() -> StationRules.ensureCanAddChild(1, 2))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("第三级目录或已有图片的目录不能添加下级");
    }

    @Test
    void allowsChildFolderBelowLevelThreeWithoutImages() {
        StationRules.ensureCanAddChild(2, 0);
    }

    @Test
    void rejectsDeletingNonEmptyFolder() {
        assertThatThrownBy(() -> StationRules.ensureFolderEmpty(0, 1))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("非空目录不能删除");
    }

    @Test
    void parsesLegacyDataUrlImage() {
        LegacyImage image = LegacyImage.fromDataUrl("hello.txt", "data:text/plain;base64,aGVsbG8=");

        assertThat(image.name()).isEqualTo("hello.txt");
        assertThat(image.contentType()).isEqualTo("text/plain");
        assertThat(image.bytes()).containsExactly('h', 'e', 'l', 'l', 'o');
    }
}
