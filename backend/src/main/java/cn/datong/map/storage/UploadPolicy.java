package cn.datong.map.storage;

import cn.datong.map.common.BusinessException;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;

@Component
public class UploadPolicy {
    public static final int MAX_IMAGE_COUNT = 20;
    public static final long MAX_IMAGE_BYTES = 20L * 1024 * 1024;
    public static final long MAX_PDF_BYTES = 50L * 1024 * 1024;
    public static final long MAX_IMPORT_BYTES = 50L * 1024 * 1024;

    public void validateBatch(MultipartFile[] files) {
        if (files == null || files.length == 0) throw new BusinessException("请选择图片");
        if (files.length > MAX_IMAGE_COUNT) throw new BusinessException("每批最多上传20张图片");
    }

    public String validateImage(MultipartFile file) {
        if (file == null || file.isEmpty()) throw new BusinessException("图片文件不能为空");
        if (file.getSize() > MAX_IMAGE_BYTES) throw new BusinessException("单张图片不能超过20MB");
        try (InputStream input = file.getInputStream()) {
            return validateImageBytes(input.readNBytes(12), file.getContentType());
        } catch (IOException ex) {
            throw new BusinessException("图片文件读取失败");
        }
    }

    public void validatePdf(MultipartFile file) {
        if (file == null || file.isEmpty()) throw new BusinessException("请上传 PDF 文件");
        if (file.getSize() > MAX_PDF_BYTES) throw new BusinessException("PDF文件不能超过50MB");
        try (InputStream input = file.getInputStream()) {
            if (!"%PDF-".equals(new String(input.readNBytes(5), StandardCharsets.US_ASCII))) {
                throw new BusinessException("PDF文件内容与格式不匹配");
            }
        } catch (IOException ex) {
            throw new BusinessException("PDF文件读取失败");
        }
    }

    public void validateLegacyImport(MultipartFile file) {
        if (file == null || file.isEmpty()) throw new BusinessException("请选择导入文件");
        if (file.getSize() > MAX_IMPORT_BYTES) throw new BusinessException("导入文件不能超过50MB");
    }

    public String validateImageBytes(byte[] bytes, String declaredType) {
        String detected = detect(bytes);
        if (detected == null) {
            if ("image/svg+xml".equalsIgnoreCase(declaredType)) throw new BusinessException("仅支持 JPEG、PNG、WebP 图片");
            throw new BusinessException("图片文件内容与格式不匹配");
        }
        if (declaredType != null && !declaredType.isBlank() && !detected.equalsIgnoreCase(declaredType)) {
            throw new BusinessException("图片文件内容与格式不匹配");
        }
        return detected;
    }

    private String detect(byte[] header) {
        if (header.length >= 3 && (header[0] & 0xff) == 0xff && (header[1] & 0xff) == 0xd8 && (header[2] & 0xff) == 0xff) {
            return "image/jpeg";
        }
        byte[] png = {(byte) 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a};
        if (header.length >= png.length && Arrays.equals(Arrays.copyOf(header, png.length), png)) return "image/png";
        if (header.length >= 12
                && "RIFF".equals(new String(header, 0, 4, StandardCharsets.US_ASCII))
                && "WEBP".equals(new String(header, 8, 4, StandardCharsets.US_ASCII))) return "image/webp";
        return null;
    }
}
