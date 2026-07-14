package cn.datong.map.layout;

import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayOutputStream;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

class PdfFirstPageRendererTest {
    @Test
    void rejectsPageThatWouldRenderToExcessivePixels() throws Exception {
        byte[] pdf;
        try (PDDocument document = new PDDocument(); ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            document.addPage(new PDPage(new PDRectangle(6000, 6000)));
            document.save(output);
            pdf = output.toByteArray();
        }

        assertThatThrownBy(() -> new PdfFirstPageRenderer().render(pdf))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("PDF页面尺寸过大");
    }
}
