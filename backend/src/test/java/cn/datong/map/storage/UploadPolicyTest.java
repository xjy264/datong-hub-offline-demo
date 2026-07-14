package cn.datong.map.storage;

import cn.datong.map.common.BusinessException;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class UploadPolicyTest {
    private final UploadPolicy policy = new UploadPolicy();

    @Test
    void acceptsSupportedImageSignatures() {
        assertThat(policy.validateImage(file("a.jpg", "image/jpeg", new byte[]{(byte) 0xff, (byte) 0xd8, (byte) 0xff, 1}))).isEqualTo("image/jpeg");
        assertThat(policy.validateImage(file("a.png", "image/png", new byte[]{(byte) 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a}))).isEqualTo("image/png");
        assertThat(policy.validateImage(file("a.webp", "image/webp", "RIFF1234WEBP".getBytes()))).isEqualTo("image/webp");
    }

    @Test
    void rejectsSvgAndForgedMimeType() {
        assertThatThrownBy(() -> policy.validateImage(file("x.svg", "image/svg+xml", "<svg/>".getBytes())))
                .isInstanceOf(BusinessException.class).hasMessage("仅支持 JPEG、PNG、WebP 图片");
        assertThatThrownBy(() -> policy.validateImage(file("x.jpg", "image/jpeg", "not-an-image".getBytes())))
                .isInstanceOf(BusinessException.class).hasMessage("图片文件内容与格式不匹配");
    }

    @Test
    void rejectsOversizedBatchBeforeReadingFiles() {
        MockMultipartFile[] files = new MockMultipartFile[21];
        for (int i = 0; i < files.length; i++) files[i] = file(i + ".png", "image/png", new byte[]{(byte) 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a});
        assertThatThrownBy(() -> policy.validateBatch(files)).hasMessage("每批最多上传20张图片");
    }

    @Test
    void rejectsForgedPdf() {
        assertThatThrownBy(() -> policy.validatePdf(file("map.pdf", "application/pdf", "not-pdf".getBytes())))
                .hasMessage("PDF文件内容与格式不匹配");
    }

    private MockMultipartFile file(String name, String type, byte[] bytes) {
        return new MockMultipartFile("files", name, type, bytes);
    }
}
