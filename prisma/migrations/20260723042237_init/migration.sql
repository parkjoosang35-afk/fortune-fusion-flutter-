-- CreateTable
CREATE TABLE "admin_roles" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);

-- CreateTable
CREATE TABLE "admin_permissions" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "role_id" INTEGER NOT NULL,
    "menu_code" TEXT NOT NULL,
    "can_read" BOOLEAN NOT NULL DEFAULT false,
    "can_write" BOOLEAN NOT NULL DEFAULT false,
    "can_delete" BOOLEAN NOT NULL DEFAULT false,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "admin_permissions_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "admin_roles" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "admin_users" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "email" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "role_id" INTEGER NOT NULL,
    "is_2fa_enabled" BOOLEAN NOT NULL DEFAULT false,
    "last_login_at" DATETIME,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "admin_users_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "admin_roles" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "admin_login_logs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "admin_user_id" INTEGER NOT NULL,
    "ip_address" TEXT NOT NULL,
    "success_flag" BOOLEAN NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "admin_login_logs_admin_user_id_fkey" FOREIGN KEY ("admin_user_id") REFERENCES "admin_users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateIndex
CREATE UNIQUE INDEX "admin_roles_code_key" ON "admin_roles"("code");

-- CreateIndex
CREATE UNIQUE INDEX "admin_permissions_role_id_menu_code_key" ON "admin_permissions"("role_id", "menu_code");

-- CreateIndex
CREATE UNIQUE INDEX "admin_users_email_key" ON "admin_users"("email");

-- CreateIndex
CREATE INDEX "admin_login_logs_admin_user_id_created_at_idx" ON "admin_login_logs"("admin_user_id", "created_at");
