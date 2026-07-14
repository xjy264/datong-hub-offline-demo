UPDATE sys_user
SET approval_status = 'APPROVED', is_super_admin = 0, updated_at = CURRENT_TIMESTAMP
WHERE deleted = 0;

UPDATE sys_user
SET status = 'DISABLED', updated_at = CURRENT_TIMESTAMP
WHERE id = 1
  AND password = '$2y$10$JLYTEoDd2O7bkkA9W176He7tuLuAMKNQ4baclBgz02t4mD8FO3joW'
  AND deleted = 0;
