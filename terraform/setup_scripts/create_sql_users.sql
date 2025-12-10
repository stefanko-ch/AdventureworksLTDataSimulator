-- ============================================================================
-- Create SQL Users for AdventureWorksLT-Live Database
-- ============================================================================
-- Run this script AFTER Terraform deployment.
-- Replace the password placeholders with values from Key Vault or Terraform output.
-- ============================================================================

USE [AdventureWorksLT-Live];
GO

-- ============================================================================
-- 1. Create Writer User (for Logic Apps simulation)
-- ============================================================================
-- Replace ${WRITER_PASSWORD} with the actual password from Key Vault
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'dbwriter')
BEGIN
    CREATE USER [dbwriter] WITH PASSWORD = '${WRITER_PASSWORD}';
    PRINT 'User dbwriter created successfully.';
END
ELSE
BEGIN
    PRINT 'User dbwriter already exists.';
END
GO

-- Grant permissions for simulation
ALTER ROLE db_datareader ADD MEMBER [dbwriter];
ALTER ROLE db_datawriter ADD MEMBER [dbwriter];
GRANT EXECUTE ON SCHEMA::SalesLT TO [dbwriter];
PRINT 'Permissions granted to dbwriter.';
GO

-- ============================================================================
-- 2. Create Reader User (for external applications like Databricks)
-- ============================================================================
-- Replace ${READER_PASSWORD} with the actual password from Key Vault
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'dbreader')
BEGIN
    CREATE USER [dbreader] WITH PASSWORD = '${READER_PASSWORD}';
    PRINT 'User dbreader created successfully.';
END
ELSE
BEGIN
    PRINT 'User dbreader already exists.';
END
GO

-- Grant read-only permissions
ALTER ROLE db_datareader ADD MEMBER [dbreader];
PRINT 'Permissions granted to dbreader.';
GO

PRINT 'All SQL users created successfully.';
GO
