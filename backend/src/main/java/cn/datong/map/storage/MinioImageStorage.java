package cn.datong.map.storage;

import cn.datong.map.common.BusinessException;
import io.minio.BucketExistsArgs;
import io.minio.GetObjectArgs;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import io.minio.RemoveObjectArgs;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.InputStream;

@Service
public class MinioImageStorage implements ImageStorage {
    private static final Logger log = LoggerFactory.getLogger(MinioImageStorage.class);
    private static final String STORAGE_UNAVAILABLE = "文件存储服务暂时不可用，请稍后重试或联系管理员。";
    private final MinioClient minioClient;
    private final String bucket;

    public MinioImageStorage(MinioClient minioClient, @Value("${app.minio.bucket:datong-map}") String bucket) {
        this.minioClient = minioClient;
        this.bucket = bucket;
    }

    @Override
    public StoredObject upload(InputStream input, long size, String contentType, String objectName) {
        try {
            ensureBucket();
            minioClient.putObject(PutObjectArgs.builder()
                    .bucket(bucket)
                    .object(objectName)
                    .contentType(contentType == null || contentType.isBlank() ? "application/octet-stream" : contentType)
                    .stream(input, size, -1)
                    .build());
            return new StoredObject(bucket, objectName, size, contentType);
        } catch (Exception ex) {
            log.error("MinIO upload failed: {}", objectName, ex);
            throw new BusinessException(STORAGE_UNAVAILABLE);
        }
    }

    @Override
    public InputStream open(String bucket, String objectName) {
        try {
            return minioClient.getObject(GetObjectArgs.builder().bucket(bucket).object(objectName).build());
        } catch (Exception ex) {
            log.error("MinIO open failed: {}/{}", bucket, objectName, ex);
            throw new BusinessException(STORAGE_UNAVAILABLE);
        }
    }

    @Override
    public void remove(String bucket, String objectName) {
        try {
            minioClient.removeObject(RemoveObjectArgs.builder().bucket(bucket).object(objectName).build());
        } catch (Exception ex) {
            log.error("MinIO remove failed: {}/{}", bucket, objectName, ex);
            throw new BusinessException(STORAGE_UNAVAILABLE);
        }
    }

    private void ensureBucket() throws Exception {
        boolean exists = minioClient.bucketExists(BucketExistsArgs.builder().bucket(bucket).build());
        if (!exists) {
            minioClient.makeBucket(MakeBucketArgs.builder().bucket(bucket).build());
        }
    }
}
