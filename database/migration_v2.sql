-- =============================================
-- Dawemly V2 Migration - Organizations, Plans, Super Admin
-- =============================================

-- ═══ Organizations (المؤسسات) ═══
CREATE TABLE IF NOT EXISTS organizations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    name_en VARCHAR(255) DEFAULT '',
    logo_url VARCHAR(500) DEFAULT '',
    email VARCHAR(255) DEFAULT '',
    phone VARCHAR(50) DEFAULT '',
    address TEXT DEFAULT NULL,
    plan_id INT DEFAULT NULL,
    active TINYINT(1) DEFAULT 1,
    subscription_start DATE DEFAULT NULL,
    subscription_end DATE DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ═══ Plans (الباقات) ═══
CREATE TABLE IF NOT EXISTS plans (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    name_en VARCHAR(100) DEFAULT '',
    max_employees INT DEFAULT 20,
    max_branches INT DEFAULT 1,
    max_locations INT DEFAULT 1,
    max_radius INT DEFAULT 500,
    max_supervisors INT DEFAULT 0,
    allow_face_auth TINYINT(1) DEFAULT 0,
    allow_reports_pdf TINYINT(1) DEFAULT 0,
    allow_reports_excel TINYINT(1) DEFAULT 0,
    allow_leave_balance TINYINT(1) DEFAULT 0,
    allow_salary_calc TINYINT(1) DEFAULT 0,
    allow_overtime TINYINT(1) DEFAULT 0,
    allow_verification TINYINT(1) DEFAULT 0,
    allow_schedules TINYINT(1) DEFAULT 1,
    price_monthly DECIMAL(10,2) DEFAULT 0,
    price_yearly DECIMAL(10,2) DEFAULT 0,
    active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ═══ Branches (الفروع) ═══
CREATE TABLE IF NOT EXISTS branches (
    id INT AUTO_INCREMENT PRIMARY KEY,
    org_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    address TEXT DEFAULT NULL,
    lat DOUBLE DEFAULT NULL,
    lng DOUBLE DEFAULT NULL,
    active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (org_id) REFERENCES organizations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ═══ Leave Balances (أرصدة الإجازات) ═══
CREATE TABLE IF NOT EXISTS leave_balances (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uid VARCHAR(64) NOT NULL,
    org_id INT DEFAULT NULL,
    year INT NOT NULL,
    annual_total INT DEFAULT 21,
    annual_used INT DEFAULT 0,
    sick_total INT DEFAULT 10,
    sick_used INT DEFAULT 0,
    emergency_total INT DEFAULT 5,
    emergency_used INT DEFAULT 0,
    unpaid_used INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_user_year (uid, year)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ═══ Salary Deductions (خصومات الرواتب) ═══
CREATE TABLE IF NOT EXISTS salary_records (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uid VARCHAR(64) NOT NULL,
    org_id INT DEFAULT NULL,
    month INT NOT NULL,
    year INT NOT NULL,
    total_working_days INT DEFAULT 0,
    days_present INT DEFAULT 0,
    days_absent INT DEFAULT 0,
    total_late_minutes INT DEFAULT 0,
    late_count INT DEFAULT 0,
    early_leave_count INT DEFAULT 0,
    overtime_minutes INT DEFAULT 0,
    overtime_amount DECIMAL(10,2) DEFAULT 0,
    deduction_absent DECIMAL(10,2) DEFAULT 0,
    deduction_late DECIMAL(10,2) DEFAULT 0,
    total_deductions DECIMAL(10,2) DEFAULT 0,
    notes TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_user_month (uid, year, month)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ═══ Super Admin table ═══
CREATE TABLE IF NOT EXISTS super_admins (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ═══ Add org_id to existing tables ═══
ALTER TABLE users ADD COLUMN IF NOT EXISTS org_id INT DEFAULT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS branch_id INT DEFAULT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS supervisor_id VARCHAR(64) DEFAULT NULL;

ALTER TABLE locations ADD COLUMN IF NOT EXISTS org_id INT DEFAULT NULL;
ALTER TABLE locations ADD COLUMN IF NOT EXISTS branch_id INT DEFAULT NULL;

ALTER TABLE attendance ADD COLUMN IF NOT EXISTS org_id INT DEFAULT NULL;
ALTER TABLE attendance_daily ADD COLUMN IF NOT EXISTS org_id INT DEFAULT NULL;

ALTER TABLE requests ADD COLUMN IF NOT EXISTS org_id INT DEFAULT NULL;

ALTER TABLE schedules ADD COLUMN IF NOT EXISTS org_id INT DEFAULT NULL;
ALTER TABLE holidays ADD COLUMN IF NOT EXISTS org_id INT DEFAULT NULL;

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS org_id INT DEFAULT NULL;
ALTER TABLE audit_log ADD COLUMN IF NOT EXISTS org_id INT DEFAULT NULL;

ALTER TABLE active_sessions ADD COLUMN IF NOT EXISTS org_id INT DEFAULT NULL;

-- ═══ Add late tracking to attendance_daily ═══
ALTER TABLE attendance_daily ADD COLUMN IF NOT EXISTS late_minutes INT DEFAULT 0;
ALTER TABLE attendance_daily ADD COLUMN IF NOT EXISTS early_leave_minutes INT DEFAULT 0;
ALTER TABLE attendance_daily ADD COLUMN IF NOT EXISTS is_late TINYINT(1) DEFAULT 0;
ALTER TABLE attendance_daily ADD COLUMN IF NOT EXISTS is_early_leave TINYINT(1) DEFAULT 0;

-- ═══ Insert default plans ═══
INSERT INTO plans (name, name_en, max_employees, max_branches, max_locations, max_radius, max_supervisors, allow_face_auth, allow_reports_pdf, allow_reports_excel, allow_leave_balance, allow_salary_calc, allow_overtime, allow_verification, price_monthly, price_yearly) VALUES
('أساسية', 'Basic', 20, 1, 2, 500, 0, 0, 0, 0, 0, 0, 0, 0, 99, 999),
('متقدمة', 'Pro', 50, 3, 5, 1000, 2, 1, 1, 1, 1, 0, 1, 1, 199, 1999),
('بريميوم', 'Premium', 200, 10, 20, 2000, 10, 1, 1, 1, 1, 1, 1, 1, 399, 3999),
('غير محدود', 'Unlimited', 99999, 99999, 99999, 5000, 99999, 1, 1, 1, 1, 1, 1, 1, 799, 7999)
ON DUPLICATE KEY UPDATE name=name;

-- ═══ Insert default organization ═══
INSERT INTO organizations (id, name, plan_id, active, subscription_start, subscription_end) VALUES
(1, 'المؤسسة الافتراضية', 4, 1, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 1 YEAR))
ON DUPLICATE KEY UPDATE name=name;

-- ═══ Update existing users to belong to default org ═══
UPDATE users SET org_id = 1 WHERE org_id IS NULL;

-- ═══ Insert default super admin ═══
INSERT INTO super_admins (email, password, name) VALUES
('super@dawemly.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Super Admin')
ON DUPLICATE KEY UPDATE email=email;

-- ═══ Insert default leave balances for existing users ═══
INSERT IGNORE INTO leave_balances (uid, org_id, year, annual_total, sick_total, emergency_total)
SELECT uid, org_id, YEAR(CURDATE()), 21, 10, 5 FROM users WHERE active = 1;
