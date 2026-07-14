UPDATE sys_user SET is_super_admin = 0 WHERE id <> 1 AND is_super_admin = 1;

CREATE INDEX idx_sys_user_admin_queue ON sys_user (approval_status, status, deleted, created_at);
