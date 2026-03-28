-- =============================================
-- Dawemly - نظام إدارة الحضور والانصراف
-- Database Schema
-- =============================================

CREATE DATABASE IF NOT EXISTS `dawemly` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `dawemly`;

-- =============================================
-- 1. المستخدمين (users)
-- =============================================
CREATE TABLE `users` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `uid` VARCHAR(50) UNIQUE NOT NULL,
    `email` VARCHAR(255) DEFAULT NULL,
    `phone` VARCHAR(20) DEFAULT NULL,
    `password` VARCHAR(255) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `dept` VARCHAR(255) DEFAULT '',
    `role` ENUM('admin', 'employee') DEFAULT 'employee',
    `emp_id` VARCHAR(50) DEFAULT NULL,
    `active` TINYINT(1) DEFAULT 1,
    `face_registered` TINYINT(1) DEFAULT 0,
    `face_photo_url` VARCHAR(500) DEFAULT NULL,
    `auth_override` TINYINT(1) DEFAULT 0,
    `auth_face` TINYINT(1) DEFAULT 0,
    `auth_biometric` TINYINT(1) DEFAULT 1,
    `auth_loc` TINYINT(1) DEFAULT 1,
    `multi_device_allowed` TINYINT(1) DEFAULT 0,
    `fcm_token` VARCHAR(500) DEFAULT NULL,
    `last_platform` VARCHAR(50) DEFAULT NULL,
    `last_device_model` VARCHAR(255) DEFAULT NULL,
    `last_os_version` VARCHAR(100) DEFAULT NULL,
    `last_device_brand` VARCHAR(255) DEFAULT NULL,
    `last_login_at` DATETIME DEFAULT NULL,
    `permissions` JSON DEFAULT NULL,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_email` (`email`),
    INDEX `idx_phone` (`phone`),
    INDEX `idx_role` (`role`),
    INDEX `idx_active` (`active`)
) ENGINE=InnoDB;

-- =============================================
-- 2. سجل الحضور التفصيلي (attendance)
-- =============================================
CREATE TABLE `attendance` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `uid` VARCHAR(50) NOT NULL,
    `emp_id` VARCHAR(50) DEFAULT NULL,
    `name` VARCHAR(255) DEFAULT NULL,
    `type` ENUM('checkIn', 'checkOut') NOT NULL,
    `timestamp` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `local_time` DATETIME DEFAULT NULL,
    `date_key` VARCHAR(10) NOT NULL COMMENT 'YYYY-MM-DD',
    `lat` DOUBLE DEFAULT NULL,
    `lng` DOUBLE DEFAULT NULL,
    `accuracy` DOUBLE DEFAULT NULL,
    `biometric` TINYINT(1) DEFAULT 0,
    `auth_method` VARCHAR(50) DEFAULT 'fingerprint',
    `face_photo_url` VARCHAR(500) DEFAULT NULL,
    INDEX `idx_uid` (`uid`),
    INDEX `idx_date_key` (`date_key`),
    INDEX `idx_uid_date` (`uid`, `date_key`),
    INDEX `idx_type` (`type`),
    FOREIGN KEY (`uid`) REFERENCES `users`(`uid`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =============================================
-- 3. ملخص الحضور اليومي (attendance_daily)
-- =============================================
CREATE TABLE `attendance_daily` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `uid` VARCHAR(50) NOT NULL,
    `emp_id` VARCHAR(50) DEFAULT NULL,
    `name` VARCHAR(255) DEFAULT NULL,
    `date_key` VARCHAR(10) NOT NULL,
    `first_check_in` DATETIME DEFAULT NULL,
    `first_check_in_lat` DOUBLE DEFAULT NULL,
    `first_check_in_lng` DOUBLE DEFAULT NULL,
    `last_check_out` DATETIME DEFAULT NULL,
    `last_check_out_lat` DOUBLE DEFAULT NULL,
    `last_check_out_lng` DOUBLE DEFAULT NULL,
    `check_in` DATETIME DEFAULT NULL,
    `check_in_lat` DOUBLE DEFAULT NULL,
    `check_in_lng` DOUBLE DEFAULT NULL,
    `check_out` DATETIME DEFAULT NULL,
    `check_out_lat` DOUBLE DEFAULT NULL,
    `check_out_lng` DOUBLE DEFAULT NULL,
    `total_worked_minutes` INT DEFAULT 0,
    `sessions` INT DEFAULT 0,
    `current_session_start` DATETIME DEFAULT NULL,
    `is_checked_in` TINYINT(1) DEFAULT 0,
    `status` VARCHAR(50) DEFAULT 'غائب',
    UNIQUE KEY `uk_uid_date` (`uid`, `date_key`),
    INDEX `idx_date_key` (`date_key`),
    INDEX `idx_status` (`status`),
    FOREIGN KEY (`uid`) REFERENCES `users`(`uid`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =============================================
-- 4. الطلبات (requests) - إجازات وأذونات
-- =============================================
CREATE TABLE `requests` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `uid` VARCHAR(50) NOT NULL,
    `emp_id` VARCHAR(50) DEFAULT NULL,
    `name` VARCHAR(255) DEFAULT NULL,
    `request_type` VARCHAR(50) NOT NULL COMMENT 'إجازة أو إذن',
    `leave_type` VARCHAR(100) DEFAULT NULL COMMENT 'سنوية، مرضية، طارئة، بدون راتب',
    `perm_type` VARCHAR(100) DEFAULT NULL COMMENT 'انصراف مبكر، تأخير عن الحضور',
    `start_date` DATE DEFAULT NULL,
    `end_date` DATE DEFAULT NULL,
    `days` INT DEFAULT 0,
    `from_time` VARCHAR(20) DEFAULT NULL,
    `to_time` VARCHAR(20) DEFAULT NULL,
    `date` DATE DEFAULT NULL,
    `hours` DOUBLE DEFAULT 0,
    `reason` TEXT DEFAULT NULL,
    `status` VARCHAR(50) DEFAULT 'تحت الإجراء',
    `admin_note` TEXT DEFAULT NULL,
    `reviewed_at` DATETIME DEFAULT NULL,
    `date_key` VARCHAR(10) DEFAULT NULL,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_uid` (`uid`),
    INDEX `idx_status` (`status`),
    FOREIGN KEY (`uid`) REFERENCES `users`(`uid`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =============================================
-- 5. الإعدادات (settings)
-- =============================================
CREATE TABLE `settings` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `setting_key` VARCHAR(100) UNIQUE NOT NULL,
    `setting_value` JSON DEFAULT NULL,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- إعدادات افتراضية
INSERT INTO `settings` (`setting_key`, `setting_value`) VALUES
('general', JSON_OBJECT(
    'authFinger', true,
    'authFace', false,
    'authLoc', true,
    'singleDeviceMode', false,
    'overtimeRate', 1.5,
    'workHoursPerDay', 8,
    'lateThreshold', 15,
    'earlyLeaveThreshold', 15
));

-- =============================================
-- 6. الجلسات النشطة (active_sessions)
-- =============================================
CREATE TABLE `active_sessions` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `uid` VARCHAR(50) UNIQUE NOT NULL,
    `user_name` VARCHAR(255) DEFAULT NULL,
    `platform` VARCHAR(50) DEFAULT NULL,
    `device_model` VARCHAR(255) DEFAULT NULL,
    `os_version` VARCHAR(100) DEFAULT NULL,
    `device_brand` VARCHAR(255) DEFAULT NULL,
    `device_id` VARCHAR(255) DEFAULT NULL,
    `login_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `last_active_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (`uid`) REFERENCES `users`(`uid`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =============================================
-- 7. بيانات الوجه (face_data)
-- =============================================
CREATE TABLE `face_data` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `uid` VARCHAR(50) UNIQUE NOT NULL,
    `user_name` VARCHAR(255) DEFAULT NULL,
    `registered` TINYINT(1) DEFAULT 0,
    `features` JSON DEFAULT NULL,
    `photo_url` VARCHAR(500) DEFAULT NULL,
    `feature_count` INT DEFAULT 0,
    `registered_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`uid`) REFERENCES `users`(`uid`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =============================================
-- 8. سجل التحقق من الوجه (face_verifications)
-- =============================================
CREATE TABLE `face_verifications` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `uid` VARCHAR(50) NOT NULL,
    `photo_url` VARCHAR(500) DEFAULT NULL,
    `similarity` DOUBLE DEFAULT 0,
    `matched` TINYINT(1) DEFAULT 0,
    `threshold` DOUBLE DEFAULT 0.65,
    `timestamp` DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_uid` (`uid`),
    FOREIGN KEY (`uid`) REFERENCES `users`(`uid`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =============================================
-- 9. المواقع (locations)
-- =============================================
CREATE TABLE `locations` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL,
    `lat` DOUBLE NOT NULL,
    `lng` DOUBLE NOT NULL,
    `radius` INT DEFAULT 200 COMMENT 'نطاق البصمة بالأمتار',
    `active` TINYINT(1) DEFAULT 1,
    `assigned_employees` JSON DEFAULT NULL COMMENT 'قائمة uid الموظفين المخصصين',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- =============================================
-- 10. جداول العمل (schedules)
-- =============================================
CREATE TABLE `schedules` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL,
    `shift_id` INT DEFAULT 1,
    `days` JSON DEFAULT NULL COMMENT 'أيام العمل',
    `emp_ids` JSON DEFAULT NULL COMMENT 'قائمة uid الموظفين',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- جداول افتراضية
INSERT INTO `schedules` (`name`, `shift_id`, `days`, `emp_ids`) VALUES
('الجدول الأساسي', 1, '["أحد","إثنين","ثلاثاء","أربعاء","خميس"]', '[]'),
('الجدول المسائي', 2, '["أحد","إثنين","ثلاثاء","أربعاء","خميس"]', '[]'),
('جدول الفترة الثالثة', 3, '["أحد","إثنين","ثلاثاء","أربعاء"]', '[]');

-- =============================================
-- 11. الإجازات الرسمية (holidays)
-- =============================================
CREATE TABLE `holidays` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL,
    `date` VARCHAR(100) NOT NULL,
    `days` INT DEFAULT 1,
    `type` VARCHAR(50) DEFAULT 'عامة',
    `emp_ids` JSON DEFAULT NULL COMMENT 'فارغ = للجميع',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- =============================================
-- 12. الإشعارات (notifications)
-- =============================================
CREATE TABLE `notifications` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `uid` VARCHAR(50) NOT NULL,
    `title` VARCHAR(255) NOT NULL,
    `body` TEXT DEFAULT NULL,
    `type` VARCHAR(50) DEFAULT 'general',
    `batch_id` VARCHAR(100) DEFAULT NULL,
    `is_read` TINYINT(1) DEFAULT 0,
    `timestamp` DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_uid` (`uid`),
    INDEX `idx_read` (`is_read`),
    FOREIGN KEY (`uid`) REFERENCES `users`(`uid`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =============================================
-- 13. طلبات التحقق (verification_requests)
-- =============================================
CREATE TABLE `verification_requests` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `batch_id` VARCHAR(100) DEFAULT NULL,
    `uid` VARCHAR(50) NOT NULL,
    `emp_id` VARCHAR(50) DEFAULT NULL,
    `emp_name` VARCHAR(255) DEFAULT NULL,
    `status` VARCHAR(50) DEFAULT 'pending',
    `sent_by` VARCHAR(255) DEFAULT NULL,
    `sent_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `responded_at` DATETIME DEFAULT NULL,
    `emp_lat` DOUBLE DEFAULT NULL,
    `emp_lng` DOUBLE DEFAULT NULL,
    `in_range` TINYINT(1) DEFAULT NULL,
    `distance` DOUBLE DEFAULT NULL,
    INDEX `idx_uid` (`uid`),
    INDEX `idx_batch` (`batch_id`),
    FOREIGN KEY (`uid`) REFERENCES `users`(`uid`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =============================================
-- 14. قائمة إرسال FCM (fcm_queue)
-- يظل يستخدم Firebase Cloud Messaging
-- =============================================
CREATE TABLE `fcm_queue` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `token` VARCHAR(500) NOT NULL,
    `title` VARCHAR(255) DEFAULT 'داوملي',
    `body` TEXT DEFAULT NULL,
    `sent` TINYINT(1) DEFAULT 0,
    `sent_at` DATETIME DEFAULT NULL,
    `error` TEXT DEFAULT NULL,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_sent` (`sent`)
) ENGINE=InnoDB;

-- =============================================
-- 15. سجل المراجعة (audit_log)
-- =============================================
CREATE TABLE `audit_log` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `uid` VARCHAR(50) DEFAULT NULL,
    `user_name` VARCHAR(255) DEFAULT NULL,
    `action` VARCHAR(255) NOT NULL,
    `details` TEXT DEFAULT NULL,
    `ip_address` VARCHAR(50) DEFAULT NULL,
    `timestamp` DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_uid` (`uid`),
    INDEX `idx_action` (`action`),
    INDEX `idx_timestamp` (`timestamp`)
) ENGINE=InnoDB;

-- =============================================
-- 16. API Tokens (للمصادقة)
-- =============================================
CREATE TABLE `api_tokens` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `uid` VARCHAR(50) NOT NULL,
    `token` VARCHAR(500) UNIQUE NOT NULL,
    `device_info` VARCHAR(500) DEFAULT NULL,
    `expires_at` DATETIME DEFAULT NULL,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_token` (`token`(255)),
    INDEX `idx_uid` (`uid`),
    FOREIGN KEY (`uid`) REFERENCES `users`(`uid`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =============================================
-- إنشاء مستخدم أدمن افتراضي
-- الباسورد: admin123 (مشفرة)
-- =============================================
INSERT INTO `users` (`uid`, `email`, `name`, `role`, `emp_id`, `active`, `password`) VALUES
('admin_001', 'admin@dawemly.com', 'مدير النظام', 'admin', 'ADMIN-001', 1, '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi');
