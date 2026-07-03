package cn.datong.map.layout;

import org.apache.pdfbox.Loader;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.rendering.ImageType;
import org.apache.pdfbox.rendering.PDFRenderer;
import org.springframework.stereotype.Component;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;

@Component
public class PdfFirstPageRenderer {
    public RenderedPage render(byte[] pdfBytes) throws Exception {
        try (PDDocument document = Loader.loadPDF(pdfBytes)) {
            if (document.getNumberOfPages() < 1) {
                throw new IllegalArgumentException("PDF 文件没有可渲染页面");
            }
            BufferedImage image = new PDFRenderer(document).renderImageWithDPI(0, 144, ImageType.RGB);
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            ImageIO.write(image, "png", output);
            return new RenderedPage(output.toByteArray(), image.getWidth(), image.getHeight());
        }
    }

    public record RenderedPage(byte[] pngBytes, int width, int height) {
    }
}
