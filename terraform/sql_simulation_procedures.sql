-- ============================================================================
-- AdventureWorksLT-Live: Data Simulation Stored Procedures
-- ============================================================================
-- These stored procedures simulate realistic database activity for
-- CDC (Change Data Capture), streaming, and incremental load exercises.
--
-- NOTE: These procedures are automatically created by Terraform.
-- No manual execution required.
-- ============================================================================
USE [AdventureWorksLT-Live];
GO

SET QUOTED_IDENTIFIER ON;
GO

-- ============================================================================
-- 1. usp_Sim_GenerateNewOrders - Creates new orders with order details
-- ============================================================================
CREATE OR ALTER PROCEDURE SalesLT.usp_Sim_GenerateNewOrders
    @OrderCount INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @i INT = 0;
    DECLARE @CustomerID INT;
    DECLARE @AddressID INT;
    DECLARE @SalesOrderID INT;
    DECLARE @OrderDate DATETIME = GETDATE();
    DECLARE @DueDate DATETIME = DATEADD(DAY, 12, GETDATE());
    DECLARE @LineCount INT;
    DECLARE @j INT;
    DECLARE @ProductID INT;
    DECLARE @UnitPrice MONEY;
    DECLARE @OrderQty SMALLINT;
    DECLARE @Discount MONEY;
    DECLARE @SubTotal MONEY;
    
    DECLARE @InsertedOrders TABLE (SalesOrderID INT);
    DECLARE @ShipMethods TABLE (Method NVARCHAR(50));
    INSERT INTO @ShipMethods VALUES ('CARGO TRANSPORT 5'), ('STANDARD SHIPPING'), ('EXPRESS DELIVERY'), ('OVERNIGHT');
    
    WHILE @i < @OrderCount
    BEGIN
        SELECT TOP 1 @CustomerID = CustomerID FROM SalesLT.Customer ORDER BY NEWID();
        
        -- Get an address that belongs to this customer, or use any address if none exists
        SELECT TOP 1 @AddressID = ca.AddressID 
        FROM SalesLT.CustomerAddress ca 
        WHERE ca.CustomerID = @CustomerID 
        ORDER BY NEWID();
        
        -- If customer has no address, use a random existing address (edge case)
        IF @AddressID IS NULL
        BEGIN
            SELECT TOP 1 @AddressID = AddressID FROM SalesLT.Address ORDER BY NEWID();
        END
        
        SET @SubTotal = 0;
        
        INSERT INTO SalesLT.SalesOrderHeader (
            RevisionNumber, OrderDate, DueDate, ShipDate, Status, OnlineOrderFlag,
            PurchaseOrderNumber, AccountNumber, CustomerID, ShipToAddressID, BillToAddressID,
            ShipMethod, CreditCardApprovalCode, SubTotal, TaxAmt, Freight, Comment, ModifiedDate
        )
        OUTPUT inserted.SalesOrderID INTO @InsertedOrders
        SELECT 0, @OrderDate, @DueDate, NULL, 1, 1,
            'PO' + CAST(ABS(CHECKSUM(NEWID())) % 100000 AS VARCHAR(10)),
            '10-4030-' + RIGHT('000000' + CAST(ABS(CHECKSUM(NEWID())) % 1000000 AS VARCHAR(6)), 6),
            @CustomerID, @AddressID, @AddressID,
            (SELECT TOP 1 Method FROM @ShipMethods ORDER BY NEWID()),
            CAST(ABS(CHECKSUM(NEWID())) % 1000000 AS VARCHAR(15)),
            0, 0, 0, 'Simulated order', GETDATE();
        
        SELECT TOP 1 @SalesOrderID = SalesOrderID FROM @InsertedOrders;
        DELETE FROM @InsertedOrders;
        
        IF @SalesOrderID IS NOT NULL
        BEGIN
            SET @LineCount = 1 + ABS(CHECKSUM(NEWID())) % 5;
            SET @j = 0;
            WHILE @j < @LineCount
            BEGIN
                SELECT TOP 1 @ProductID = ProductID, @UnitPrice = ListPrice FROM SalesLT.Product WHERE ListPrice > 0 ORDER BY NEWID();
                SET @OrderQty = 1 + ABS(CHECKSUM(NEWID())) % 10;
                SET @Discount = CASE WHEN ABS(CHECKSUM(NEWID())) % 10 < 2 THEN 0.10 ELSE 0.00 END;
                INSERT INTO SalesLT.SalesOrderDetail (SalesOrderID, OrderQty, ProductID, UnitPrice, UnitPriceDiscount, ModifiedDate)
                VALUES (@SalesOrderID, @OrderQty, @ProductID, @UnitPrice, @Discount, GETDATE());
                SET @SubTotal = @SubTotal + (@OrderQty * @UnitPrice * (1 - @Discount));
                SET @j = @j + 1;
            END
            UPDATE SalesLT.SalesOrderHeader SET SubTotal = @SubTotal, TaxAmt = ROUND(@SubTotal * 0.08, 2), Freight = ROUND(@SubTotal * 0.025, 2), ModifiedDate = GETDATE() WHERE SalesOrderID = @SalesOrderID;
        END
        SET @i = @i + 1;
    END
    SELECT @OrderCount AS OrdersCreated, GETDATE() AS ExecutedAt;
END
GO

-- ============================================================================
-- 2. usp_Sim_ShipPendingOrders - Ships approximately 50% of pending orders
-- ============================================================================
CREATE OR ALTER PROCEDURE SalesLT.usp_Sim_ShipPendingOrders
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ShippedCount INT;
    UPDATE SalesLT.SalesOrderHeader SET Status = 5, ShipDate = GETDATE(), RevisionNumber = RevisionNumber + 1, ModifiedDate = GETDATE() WHERE Status = 1 AND ABS(CHECKSUM(NEWID())) % 100 < 50;
    SET @ShippedCount = @@ROWCOUNT;
    SELECT @ShippedCount AS OrdersShipped, GETDATE() AS ExecutedAt;
END
GO

-- ============================================================================
-- 3. usp_Sim_UpdateCustomerInfo - Updates phone numbers for random customers
-- ============================================================================
CREATE OR ALTER PROCEDURE SalesLT.usp_Sim_UpdateCustomerInfo
    @UpdateCount INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ActualUpdateCount INT;
    DECLARE @AreaCodes TABLE (Code VARCHAR(3));
    INSERT INTO @AreaCodes VALUES ('415'), ('650'), ('510'), ('408'), ('925'), ('707'), ('831'), ('209');
    
    UPDATE c 
    SET Phone = (SELECT TOP 1 Code FROM @AreaCodes ORDER BY NEWID()) + '-' + 
                RIGHT('000' + CAST(ABS(CHECKSUM(NEWID())) % 1000 AS VARCHAR(3)), 3) + '-' + 
                RIGHT('0000' + CAST(ABS(CHECKSUM(NEWID())) % 10000 AS VARCHAR(4)), 4), 
        ModifiedDate = GETDATE() 
    FROM SalesLT.Customer c 
    WHERE c.CustomerID IN (SELECT TOP (@UpdateCount) CustomerID FROM SalesLT.Customer ORDER BY NEWID());
    
    SET @ActualUpdateCount = @@ROWCOUNT;
    SELECT @ActualUpdateCount AS CustomersUpdated, GETDATE() AS ExecutedAt;
END
GO

-- ============================================================================
-- 4. usp_Sim_GenerateNewCustomers - Creates new customers with addresses
-- ============================================================================
CREATE OR ALTER PROCEDURE SalesLT.usp_Sim_GenerateNewCustomers
    @MinCount INT = 10,
    @MaxCount INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CustomerCount INT = @MinCount + ABS(CHECKSUM(NEWID())) % (@MaxCount - @MinCount + 1);
    DECLARE @i INT = 0, @CustomerID INT, @AddressID INT, @FirstName NVARCHAR(50), @LastName NVARCHAR(50);
    DECLARE @InsertedCustomers TABLE (CustomerID INT);
    DECLARE @InsertedAddresses TABLE (AddressID INT);
    
    DECLARE @FirstNames TABLE (Name NVARCHAR(50));
    INSERT INTO @FirstNames VALUES ('Emma'),('Liam'),('Olivia'),('Noah'),('Ava'),('Oliver'),('Sophia'),('James'),('Mia'),('William'),('Charlotte'),('Lucas'),('Harper'),('Henry'),('Ella'),('Daniel'),('Chloe'),('David'),('Grace');
    
    DECLARE @LastNames TABLE (Name NVARCHAR(50));
    INSERT INTO @LastNames VALUES ('Smith'),('Johnson'),('Williams'),('Brown'),('Jones'),('Garcia'),('Miller'),('Davis'),('Martinez'),('Lopez'),('Wilson'),('Anderson'),('Thomas'),('Taylor'),('Moore');
    
    DECLARE @Cities TABLE (City NVARCHAR(30), StateProvince NVARCHAR(50), PostalCode NVARCHAR(15));
    INSERT INTO @Cities VALUES ('San Francisco','California','94102'),('Los Angeles','California','90001'),('Seattle','Washington','98101'),('Denver','Colorado','80201'),('Phoenix','Arizona','85001'),('Austin','Texas','78701'),('Chicago','Illinois','60601'),('New York','New York','10001'),('Boston','Massachusetts','02101');
    
    DECLARE @Streets TABLE (Street NVARCHAR(60));
    INSERT INTO @Streets VALUES ('Main Street'),('Oak Avenue'),('Maple Drive'),('Cedar Lane'),('Pine Road'),('Elm Street'),('Park Avenue'),('Lake Drive');
    
    DECLARE @SalesPersons TABLE (Name NVARCHAR(256));
    INSERT INTO @SalesPersons SELECT DISTINCT SalesPerson FROM SalesLT.Customer WHERE SalesPerson IS NOT NULL;
    
    WHILE @i < @CustomerCount
    BEGIN
        SELECT TOP 1 @FirstName = Name FROM @FirstNames ORDER BY NEWID();
        SELECT TOP 1 @LastName = Name FROM @LastNames ORDER BY NEWID();
        
        INSERT INTO SalesLT.Customer (NameStyle, Title, FirstName, MiddleName, LastName, CompanyName, SalesPerson, EmailAddress, Phone, PasswordHash, PasswordSalt, ModifiedDate)
        OUTPUT inserted.CustomerID INTO @InsertedCustomers
        SELECT 0, CASE ABS(CHECKSUM(NEWID())) % 3 WHEN 0 THEN 'Mr.' WHEN 1 THEN 'Ms.' ELSE NULL END, @FirstName, NULL, @LastName,
            CASE WHEN ABS(CHECKSUM(NEWID())) % 2 = 0 THEN @LastName + ' Inc.' ELSE NULL END,
            (SELECT TOP 1 Name FROM @SalesPersons ORDER BY NEWID()),
            LOWER(@FirstName) + '.' + LOWER(@LastName) + CAST(ABS(CHECKSUM(NEWID())) % 10000 AS VARCHAR(10)) + '@adventure-works.com',
            '415-' + RIGHT('000' + CAST(ABS(CHECKSUM(NEWID())) % 1000 AS VARCHAR(3)), 3) + '-' + RIGHT('0000' + CAST(ABS(CHECKSUM(NEWID())) % 10000 AS VARCHAR(4)), 4),
            CONVERT(VARCHAR(128), HASHBYTES('SHA2_256', CAST(NEWID() AS VARCHAR(36))), 2),
            SUBSTRING(CONVERT(VARCHAR(36), NEWID()), 1, 10), GETDATE();
        
        SELECT TOP 1 @CustomerID = CustomerID FROM @InsertedCustomers;
        DELETE FROM @InsertedCustomers;
        
        IF @CustomerID IS NOT NULL
        BEGIN
            INSERT INTO SalesLT.Address (AddressLine1, City, StateProvince, CountryRegion, PostalCode, ModifiedDate)
            OUTPUT inserted.AddressID INTO @InsertedAddresses
            SELECT TOP 1 CAST(100 + ABS(CHECKSUM(NEWID())) % 9900 AS VARCHAR(10)) + ' ' + Street, City, StateProvince, 'United States', PostalCode, GETDATE()
            FROM @Cities c CROSS JOIN @Streets s ORDER BY NEWID();
            
            SELECT TOP 1 @AddressID = AddressID FROM @InsertedAddresses;
            DELETE FROM @InsertedAddresses;
            
            IF @AddressID IS NOT NULL
            BEGIN
                INSERT INTO SalesLT.CustomerAddress (CustomerID, AddressID, AddressType, ModifiedDate) VALUES (@CustomerID, @AddressID, 'Main Office', GETDATE());
            END
        END
        SET @i = @i + 1;
    END
    SELECT @CustomerCount AS CustomersCreated, GETDATE() AS ExecutedAt;
END
GO

-- ============================================================================
-- 5. usp_Sim_CancelRandomOrders - Cancels approximately 10% of pending orders
-- ============================================================================
CREATE OR ALTER PROCEDURE SalesLT.usp_Sim_CancelRandomOrders
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CancelledCount INT;
    DECLARE @OrdersToCancel TABLE (SalesOrderID INT);
    
    -- Select ~10% of pending orders to cancel
    INSERT INTO @OrdersToCancel 
    SELECT SalesOrderID 
    FROM SalesLT.SalesOrderHeader 
    WHERE Status = 1 AND ABS(CHECKSUM(NEWID())) % 100 < 10;
    
    -- Delete order details first (foreign key constraint)
    DELETE FROM SalesLT.SalesOrderDetail 
    WHERE SalesOrderID IN (SELECT SalesOrderID FROM @OrdersToCancel);
    
    -- Delete order headers and count
    DELETE FROM SalesLT.SalesOrderHeader 
    WHERE SalesOrderID IN (SELECT SalesOrderID FROM @OrdersToCancel);
    
    SET @CancelledCount = @@ROWCOUNT;
    
    SELECT @CancelledCount AS OrdersCancelled, GETDATE() AS ExecutedAt;
END
GO

-- ============================================================================
-- 6. usp_Sim_GetStatus - Returns current database statistics
-- ============================================================================
CREATE OR ALTER PROCEDURE SalesLT.usp_Sim_GetStatus
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        (SELECT COUNT(*) FROM SalesLT.Customer) AS TotalCustomers,
        (SELECT COUNT(*) FROM SalesLT.Address) AS TotalAddresses,
        (SELECT COUNT(*) FROM SalesLT.SalesOrderHeader) AS TotalOrders,
        (SELECT COUNT(*) FROM SalesLT.SalesOrderHeader WHERE Status = 1) AS PendingOrders,
        (SELECT COUNT(*) FROM SalesLT.SalesOrderHeader WHERE Status = 5) AS ShippedOrders,
        (SELECT COUNT(*) FROM SalesLT.SalesOrderDetail) AS TotalOrderLines,
        GETDATE() AS CurrentTime;
END
GO

PRINT 'All simulation stored procedures created successfully.';
GO
