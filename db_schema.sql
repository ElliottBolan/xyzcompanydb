-- Drop database if exists and create a new one
DROP DATABASE IF EXISTS xyzcompany;
CREATE DATABASE xyzcompany;
USE xyzcompany;

-- Department table (Requirement 1)
CREATE TABLE Department (
    DepartmentID INT PRIMARY KEY,
    DepartmentName VARCHAR(50) NOT NULL
);

-- Person table (Requirement 2)
CREATE TABLE Person (
    PersonalID INT PRIMARY KEY,
    LastName VARCHAR(50) NOT NULL,
    FirstName VARCHAR(50) NOT NULL,
    Age INT CHECK (Age < 65),
    Gender CHAR(1),
    AddressLine1 VARCHAR(100) NOT NULL,
    AddressLine2 VARCHAR(100),
    City VARCHAR(50) NOT NULL,
    State VARCHAR(50) NOT NULL,
    ZipCode VARCHAR(10) NOT NULL,
    Email VARCHAR(100)
);

-- Phone numbers - multivalued attribute for Person (Requirement 2f)
CREATE TABLE PersonPhone (
    PersonalID INT,
    PhoneNumber VARCHAR(20) NOT NULL,
    PhoneType VARCHAR(20) NOT NULL, -- e.g., Home, Work, Mobile
    PRIMARY KEY (PersonalID, PhoneNumber),
    FOREIGN KEY (PersonalID) REFERENCES Person(PersonalID) ON DELETE CASCADE
);

-- Employee table (Requirement 2 - specific attributes for employees)
CREATE TABLE Employee (
    PersonalID INT PRIMARY KEY,
    EmployeeID VARCHAR(20) UNIQUE NOT NULL,
    EmployeeRank VARCHAR(50),
    Title VARCHAR(50),
    SupervisorID INT,
    CurrentDepartmentID INT,
    HireDate DATE NOT NULL,
    FOREIGN KEY (PersonalID) REFERENCES Person(PersonalID) ON DELETE CASCADE,
    FOREIGN KEY (SupervisorID) REFERENCES Employee(PersonalID),
    FOREIGN KEY (CurrentDepartmentID) REFERENCES Department(DepartmentID)
);

-- Customer table (Requirement 2 - specific attributes for customers)
CREATE TABLE Customer (
    PersonalID INT PRIMARY KEY,
    CustomerID VARCHAR(20) UNIQUE NOT NULL,
    PreferredSalesRepID INT,
    CustomerSince DATE NOT NULL,
    FOREIGN KEY (PersonalID) REFERENCES Person(PersonalID) ON DELETE CASCADE,
    FOREIGN KEY (PreferredSalesRepID) REFERENCES Employee(PersonalID)
);

-- Potential Employee table (Requirement 2 - subclass for potential employees)
CREATE TABLE PotentialEmployee (
    PersonalID INT PRIMARY KEY,
    PotentialEmployeeID VARCHAR(20) UNIQUE NOT NULL,
    ApplicationDate DATE NOT NULL,
    Resume TEXT,
    FOREIGN KEY (PersonalID) REFERENCES Person(PersonalID) ON DELETE CASCADE
);

-- Department Assignment History (Requirement 3)
CREATE TABLE DepartmentAssignment (
    AssignmentID INT PRIMARY KEY AUTO_INCREMENT,
    EmployeeID INT NOT NULL,
    DepartmentID INT NOT NULL,
    StartTime DATETIME NOT NULL,
    EndTime DATETIME,
    FOREIGN KEY (EmployeeID) REFERENCES Employee(PersonalID),
    FOREIGN KEY (DepartmentID) REFERENCES Department(DepartmentID),
    CHECK (EndTime IS NULL OR EndTime > StartTime)
);

-- Job Position (Requirement 4)
CREATE TABLE JobPosition (
    JobID INT PRIMARY KEY,
    JobDescription TEXT NOT NULL,
    PostedDate DATE NOT NULL,
    DepartmentID INT NOT NULL,
    Status VARCHAR(20) DEFAULT 'Open' CHECK (Status IN ('Open', 'Closed', 'Filled')),
    FOREIGN KEY (DepartmentID) REFERENCES Department(DepartmentID)
);

-- Job Application (Requirement 5)
CREATE TABLE JobApplication (
    ApplicationID INT PRIMARY KEY AUTO_INCREMENT,
    JobID INT NOT NULL,
    ApplicantID INT NOT NULL,
    ApplicationDate DATE NOT NULL,
    Status VARCHAR(20) DEFAULT 'Pending' CHECK (Status IN ('Pending', 'Selected for Interview', 'Rejected', 'Hired')),
    FOREIGN KEY (JobID) REFERENCES JobPosition(JobID),
    FOREIGN KEY (ApplicantID) REFERENCES Person(PersonalID)
);

-- Interview (Requirement 6 and 7)
CREATE TABLE Interview (
    InterviewID INT PRIMARY KEY AUTO_INCREMENT,
    ApplicationID INT NOT NULL,
    JobID INT NOT NULL,
    CandidateID INT NOT NULL,
    InterviewDate DATETIME NOT NULL,
    InterviewRound INT NOT NULL,
    Grade INT CHECK (Grade >= 0 AND Grade <= 100),
    PassStatus VARCHAR(10) GENERATED ALWAYS AS (CASE WHEN Grade >= 60 THEN 'Pass' ELSE 'Fail' END) STORED,
    FOREIGN KEY (ApplicationID) REFERENCES JobApplication(ApplicationID),
    FOREIGN KEY (JobID) REFERENCES JobPosition(JobID),
    FOREIGN KEY (CandidateID) REFERENCES Person(PersonalID)
);

-- Interview Interviewers (many-to-many relationship for interviewers)
CREATE TABLE InterviewInterviewer (
    InterviewID INT,
    InterviewerID INT,
    PRIMARY KEY (InterviewID, InterviewerID),
    FOREIGN KEY (InterviewID) REFERENCES Interview(InterviewID),
    FOREIGN KEY (InterviewerID) REFERENCES Employee(PersonalID)
);

-- Product (Requirement 8)
CREATE TABLE Product (
    ProductID INT PRIMARY KEY,
    ProductType VARCHAR(50) NOT NULL,
    Size VARCHAR(50),
    ListPrice DECIMAL(10, 2) NOT NULL,
    Weight DECIMAL(10, 2),
    Style VARCHAR(50)
);

-- Marketing Site (Requirement 9)
CREATE TABLE MarketingSite (
    SiteID INT PRIMARY KEY,
    SiteName VARCHAR(100) NOT NULL,
    SiteLocation VARCHAR(200) NOT NULL
);

-- Site Employees (Requirement 10 - many-to-many relationship)
CREATE TABLE SiteEmployee (
    SiteID INT,
    EmployeeID INT,
    AssignmentDate DATE NOT NULL,
    Role VARCHAR(50),
    PRIMARY KEY (SiteID, EmployeeID),
    FOREIGN KEY (SiteID) REFERENCES MarketingSite(SiteID),
    FOREIGN KEY (EmployeeID) REFERENCES Employee(PersonalID)
);

-- Sales (Requirement 10)
CREATE TABLE Sale (
    SaleID INT PRIMARY KEY AUTO_INCREMENT,
    ProductID INT NOT NULL,
    CustomerID INT NOT NULL,
    SalesmanID INT NOT NULL,
    SiteID INT NOT NULL,
    SaleDate DATETIME NOT NULL,
    Quantity INT NOT NULL,
    SaleAmount DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (ProductID) REFERENCES Product(ProductID),
    FOREIGN KEY (CustomerID) REFERENCES Customer(PersonalID),
    FOREIGN KEY (SalesmanID) REFERENCES Employee(PersonalID),
    FOREIGN KEY (SiteID) REFERENCES MarketingSite(SiteID)
);

-- Vendor (Requirement 11)
CREATE TABLE Vendor (
    VendorID INT PRIMARY KEY,
    VendorName VARCHAR(100) NOT NULL,
    AddressLine1 VARCHAR(100) NOT NULL,
    AddressLine2 VARCHAR(100),
    City VARCHAR(50) NOT NULL,
    State VARCHAR(50) NOT NULL,
    ZipCode VARCHAR(10) NOT NULL,
    AccountNumber VARCHAR(50) NOT NULL,
    CreditRating INT CHECK (CreditRating BETWEEN 1 AND 10),
    PurchasingWebServiceURL VARCHAR(255)
);

-- Part (Requirement 12)
CREATE TABLE Part (
    PartID INT PRIMARY KEY AUTO_INCREMENT,
    PartType VARCHAR(50) NOT NULL,
    Description TEXT,
    Weight DECIMAL(10, 2)
);

-- Vendor Part (Requirement 12 - vendor specific part information)
CREATE TABLE VendorPart (
    VendorID INT,
    PartID INT,
    Price DECIMAL(10, 2) NOT NULL,
    PartNumber VARCHAR(50),
    LeadTimeDays INT,
    PRIMARY KEY (VendorID, PartID),
    FOREIGN KEY (VendorID) REFERENCES Vendor(VendorID),
    FOREIGN KEY (PartID) REFERENCES Part(PartID)
);

-- Product Parts (Requirement 12 - parts used in products)
CREATE TABLE ProductPart (
    ProductID INT,
    PartID INT,
    Quantity INT NOT NULL,
    PRIMARY KEY (ProductID, PartID),
    FOREIGN KEY (ProductID) REFERENCES Product(ProductID),
    FOREIGN KEY (PartID) REFERENCES Part(PartID)
);

-- Salary Transaction (Requirement 13)
CREATE TABLE SalaryTransaction (
    TransactionNumber INT,
    EmployeeID INT,
    PayDate DATE NOT NULL,
    Amount DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (TransactionNumber, EmployeeID),
    FOREIGN KEY (EmployeeID) REFERENCES Employee(PersonalID)
);

-- Views

-- View1: Average monthly salary for each employee
CREATE VIEW View1 AS
SELECT 
    e.EmployeeID,
    p.FirstName,
    p.LastName,
    AVG(st.Amount) AS AverageMonthlySalary
FROM 
    Employee e
JOIN 
    Person p ON e.PersonalID = p.PersonalID
JOIN 
    SalaryTransaction st ON e.PersonalID = st.EmployeeID
GROUP BY 
    e.EmployeeID, p.FirstName, p.LastName;

-- View2: Number of interview rounds each interviewee passes for each job position
CREATE VIEW View2 AS
SELECT 
    ja.ApplicantID,
    p.FirstName,
    p.LastName,
    ja.JobID,
    COUNT(CASE WHEN i.Grade >= 60 THEN 1 END) AS PassedRounds
FROM 
    JobApplication ja
JOIN 
    Person p ON ja.ApplicantID = p.PersonalID
JOIN 
    Interview i ON ja.ApplicationID = i.ApplicationID
GROUP BY 
    ja.ApplicantID, p.FirstName, p.LastName, ja.JobID;

-- View3: Number of items of each product type sold
CREATE VIEW View3 AS
SELECT 
    p.ProductType,
    SUM(s.Quantity) AS TotalItemsSold
FROM 
    Product p
JOIN 
    Sale s ON p.ProductID = s.ProductID
GROUP BY 
    p.ProductType;

-- View4: Part purchase cost for each product
CREATE VIEW View4 AS
SELECT 
    p.ProductID,
    p.ProductType,
    SUM(pp.Quantity * vp_min_price.MinPrice) AS TotalPartCost
FROM 
    Product p
JOIN 
    ProductPart pp ON p.ProductID = pp.ProductID
JOIN 
    Part pt ON pp.PartID = pt.PartID
LEFT JOIN 
    (
        SELECT PartID, MIN(Price) AS MinPrice
        FROM VendorPart
        GROUP BY PartID
    ) vp_min_price ON pt.PartID = vp_min_price.PartID
GROUP BY 
    p.ProductID, p.ProductType;
    
    
    
    
    
    
    
    
    
-- Department
INSERT INTO Department (DepartmentID, DepartmentName) VALUES (10, 'HR');

-- Person (Hellen Cole + Interviewer)
INSERT INTO Person VALUES (100, 'Cole', 'Hellen', 30, 'F', '123 X', NULL, 'Dallas', 'TX', '75001', 'hellen.cole@email.com');
INSERT INTO Person VALUES (101, 'Nguyen', 'Tom', 40, 'M', '999 Y', NULL, 'Plano', 'TX', '75002', 'tom.nguyen@email.com');

-- Employee (Interviewer)
INSERT INTO Employee VALUES (101, 'E101', 'Senior', 'Manager', NULL, 10, '2010-01-01');

-- JobPosition for job "11111"
INSERT INTO JobPosition VALUES (11111, 'Marketing Lead', '2011-01-05', 10, 'Open');

-- JobApplication for Hellen Cole
INSERT INTO JobApplication (ApplicationID, JobID, ApplicantID, ApplicationDate, Status)
VALUES (1, 11111, 100, '2011-01-10', 'Pending');

-- Interview
INSERT INTO Interview (InterviewID, ApplicationID, JobID, CandidateID, InterviewDate, InterviewRound, Grade)
VALUES (1, 1, 11111, 100, '2011-01-15 09:00:00', 1, 85);

-- InterviewInterviewer
INSERT INTO InterviewInterviewer (InterviewID, InterviewerID) VALUES (1, 101);

INSERT INTO Department (DepartmentID, DepartmentName) VALUES (20, 'Marketing');
INSERT INTO JobPosition (JobID, JobDescription, PostedDate, DepartmentID, Status)
VALUES (20001, 'Marketing Specialist', '2011-01-14', 20, 'Open');


-- Person/Employee with no supervisees
INSERT INTO Person VALUES (102, 'Wong', 'Lisa', 33, 'F', '456 Z', NULL, 'Austin', 'TX', '75003', 'lisa.wong@email.com');
INSERT INTO Employee VALUES (102, 'E102', 'Staff', 'Analyst', NULL, 10, '2012-01-01');


INSERT INTO MarketingSite (SiteID, SiteName, SiteLocation) VALUES (300, 'Uptown', '333 Main St, Houston, TX');
-- (No sales records for this site in March 2011)


INSERT INTO JobPosition (JobID, JobDescription, PostedDate, DepartmentID, Status)
VALUES (12345, 'Accountant', '2011-04-01', 10, 'Open'); -- not filled after 1 month


-- Product Types > $200
INSERT INTO Product VALUES (501, 'LuxuryWidget', 'Large', 300.00, 10.0, 'Premium');
INSERT INTO Product VALUES (502, 'UltraGadget', 'Medium', 250.00, 6.0, 'Modern');

-- Person/Employee as Salesman
INSERT INTO Person VALUES (103, 'Smith', 'Bob', 31, 'M', '123 Sale', NULL, 'Dallas', 'TX', '75004', 'bob.smith@email.com');
INSERT INTO Employee VALUES (103, 'E103', 'Sales', 'Salesman', NULL, 20, '2010-03-01');

-- Customer for sales
INSERT INTO Person VALUES (104, 'Johnson', 'Sue', 40, 'F', '555 Sell', NULL, 'Dallas', 'TX', '75005', 'sue.j@email.com');
INSERT INTO Customer VALUES (104, 'C104', 103, '2010-03-01');

-- Marketing Site
INSERT INTO MarketingSite (SiteID, SiteName, SiteLocation) VALUES (400, 'Outlet', '555 Commerce, Dallas, TX');

-- Sales records
INSERT INTO Sale (ProductID, CustomerID, SalesmanID, SiteID, SaleDate, Quantity, SaleAmount)
VALUES (501, 104, 103, 400, '2011-01-15 11:00:00', 1, 300.00),
       (502, 104, 103, 400, '2011-01-16 12:00:00', 1, 250.00);


INSERT INTO Department (DepartmentID, DepartmentName) VALUES (30, 'Finance');
-- No jobs posted for Finance in this period.


-- Reusing employee Lisa Wong from earlier (102)
INSERT INTO JobApplication (ApplicationID, JobID, ApplicantID, ApplicationDate, Status)
VALUES (2, 12345, 102, '2011-04-05', 'Pending');


INSERT INTO Product VALUES (601, 'MegaWidget', 'XL', 400.00, 12.0, 'Modern');
-- More sales of this product
INSERT INTO Sale (ProductID, CustomerID, SalesmanID, SiteID, SaleDate, Quantity, SaleAmount)
VALUES (601, 104, 103, 400, '2011-01-17 14:00:00', 10, 4000.00);


-- Part and VendorPart (so we can calculate cost)
INSERT INTO Part (PartID, PartType, Description, Weight) VALUES (50, 'Cup', 'Plastic Cup', 3.5);
INSERT INTO Vendor (VendorID, VendorName, AddressLine1, AddressLine2, City, State, ZipCode, AccountNumber, CreditRating, PurchasingWebServiceURL)
VALUES (70, 'BestVendor', '1 Main', NULL, 'Dallas', 'TX', '75011', 'AC555', 9, NULL);
INSERT INTO VendorPart (VendorID, PartID, Price, PartNumber, LeadTimeDays)
VALUES (70, 50, 1.00, 'CUP-1', 2);

-- ProductPart links Cup to a product
INSERT INTO ProductPart (ProductID, PartID, Quantity) VALUES (601, 50, 1);
-- ProductID 601 (MegaWidget) is the best seller


-- DepartmentAssignment for Bob Smith (E103)
INSERT INTO DepartmentAssignment (EmployeeID, DepartmentID, StartTime, EndTime)
VALUES (103, 10, '2010-03-01 09:00:00', NULL), -- HR
       (103, 20, '2010-04-01 09:00:00', NULL), -- Marketing
       (103, 30, '2010-05-01 09:00:00', NULL); -- Finance


-- Use Hellen Cole (100) as selected
UPDATE JobApplication SET Status='Hired' WHERE ApplicantID=100 AND JobID=11111;


-- PersonPhone for Hellen Cole
INSERT INTO PersonPhone VALUES (100, '214-555-0000', 'Mobile');
-- (Already hired in previous JobApplication)


-- SalaryTransaction for Bob Smith (E103)
INSERT INTO SalaryTransaction (TransactionNumber, EmployeeID, PayDate, Amount)
VALUES (1, 103, '2011-01-01', 10000.00),
       (2, 103, '2011-02-01', 10000.00),
       (3, 103, '2011-03-01', 10000.00);


-- Already inserted above (Vendor 70, Part 50, price 1.00)
-- Make sure another vendor has a higher price for the same part to verify "lowest"
INSERT INTO Vendor (VendorID, VendorName, AddressLine1, AddressLine2, City, State, ZipCode, AccountNumber, CreditRating, PurchasingWebServiceURL)
VALUES (71, 'ExpensiveVendor', '2 Main', NULL, 'Dallas', 'TX', '75012', 'AC556', 8, NULL);
INSERT INTO VendorPart (VendorID, PartID, Price, PartNumber, LeadTimeDays)
VALUES (71, 50, 5.00, 'CUP-2', 3);





















SELECT DISTINCT
    e.EmployeeID,
    p.FirstName,
    p.LastName
FROM
    InterviewInterviewer ii
    JOIN Employee e ON ii.InterviewerID = e.PersonalID
    JOIN Person p ON e.PersonalID = p.PersonalID
    JOIN Interview i ON ii.InterviewID = i.InterviewID
    JOIN JobApplication ja ON i.ApplicationID = ja.ApplicationID
    JOIN Person ip ON ja.ApplicantID = ip.PersonalID
WHERE
    ip.FirstName = 'Hellen' AND ip.LastName = 'Cole'
    AND i.JobID = 11111;









SELECT
    jp.JobID
FROM
    JobPosition jp
    JOIN Department d ON jp.DepartmentID = d.DepartmentID
WHERE
    d.DepartmentName = 'Marketing'
    AND jp.PostedDate BETWEEN '2011-01-01' AND '2011-01-31';
    
    
    
    
    
    
    
    
    
    
    
    SELECT
    e.EmployeeID,
    p.FirstName,
    p.LastName
FROM
    Employee e
    JOIN Person p ON e.PersonalID = p.PersonalID
WHERE
    e.PersonalID NOT IN (
        SELECT DISTINCT SupervisorID FROM Employee WHERE SupervisorID IS NOT NULL
    );
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    SELECT
    ms.SiteID,
    ms.SiteLocation
FROM
    MarketingSite ms
WHERE
    ms.SiteID NOT IN (
        SELECT s.SiteID
        FROM Sale s
        WHERE s.SaleDate >= '2011-03-01' AND s.SaleDate < '2011-04-01'
    );













SELECT
    jp.JobID,
    jp.JobDescription
FROM
    JobPosition jp
WHERE
    jp.Status <> 'Filled'
    AND jp.PostedDate <= CURDATE() - INTERVAL 1 MONTH
    AND NOT EXISTS (
        SELECT 1 FROM JobApplication ja
        WHERE ja.JobID = jp.JobID AND ja.Status = 'Hired'
              AND ja.ApplicationDate <= jp.PostedDate + INTERVAL 1 MONTH
    );











SELECT
    e.EmployeeID,
    p.FirstName,
    p.LastName
FROM
    Employee e
    JOIN Person p ON e.PersonalID = p.PersonalID
WHERE NOT EXISTS (
    SELECT 1 FROM Product pr
    WHERE pr.ListPrice > 200
    AND NOT EXISTS (
        SELECT 1 FROM Sale s
        WHERE s.ProductID = pr.ProductID
          AND s.SalesmanID = e.PersonalID
    )
);












SELECT
    d.DepartmentID,
    d.DepartmentName
FROM
    Department d
WHERE
    d.DepartmentID NOT IN (
        SELECT DepartmentID FROM JobPosition
        WHERE PostedDate BETWEEN '2011-01-01' AND '2011-02-01'
    );
    
    
    
    
    
    
    
    
    
    
    
    
    SELECT
    e.EmployeeID,
    p.FirstName,
    p.LastName,
    e.CurrentDepartmentID
FROM
    JobApplication ja
    JOIN Employee e ON ja.ApplicantID = e.PersonalID
    JOIN Person p ON e.PersonalID = p.PersonalID
WHERE
    ja.JobID = 12345;









SELECT
    p.ProductType
FROM
    Product p
    JOIN Sale s ON p.ProductID = s.ProductID
GROUP BY
    p.ProductType
ORDER BY
    SUM(s.Quantity) DESC
LIMIT 1;












SELECT
    pr.ProductType,
    (SUM(s.SaleAmount) - IFNULL(SUM(pp.Quantity * vp.Price), 0)) AS NetProfit
FROM
    Product pr
    JOIN Sale s ON pr.ProductID = s.ProductID
    LEFT JOIN ProductPart pp ON pr.ProductID = pp.ProductID
    LEFT JOIN VendorPart vp ON pp.PartID = vp.PartID
GROUP BY
    pr.ProductID, pr.ProductType
ORDER BY
    NetProfit DESC
LIMIT 1;













SELECT
    e.EmployeeID,
    p.FirstName,
    p.LastName
FROM
    Employee e
    JOIN Person p ON e.PersonalID = p.PersonalID
WHERE NOT EXISTS (
    SELECT 1 FROM Department d
    WHERE d.DepartmentID NOT IN (
        SELECT da.DepartmentID FROM DepartmentAssignment da
        WHERE da.EmployeeID = e.PersonalID
        AND da.StartTime >= e.HireDate
    )
);









SELECT DISTINCT
    p.FirstName,
    p.LastName,
    p.Email
FROM
    JobApplication ja
    JOIN Person p ON ja.ApplicantID = p.PersonalID
WHERE
    ja.Status = 'Hired';














SELECT DISTINCT
    p.FirstName,
    p.LastName,
    ph.PhoneNumber,
    p.Email
FROM
    JobApplication ja
    JOIN Person p ON ja.ApplicantID = p.PersonalID
    JOIN PersonPhone ph ON p.PersonalID = ph.PersonalID
WHERE
    ja.Status = 'Hired';














SELECT
    v.VendorID,
    v.VendorName
FROM
    Vendor v
    JOIN VendorPart vp ON v.VendorID = vp.VendorID
    JOIN Part p ON vp.PartID = p.PartID
WHERE
    p.PartType = 'Cup'
    AND p.Weight < 4
    AND vp.Price = (
        SELECT MIN(vp2.Price)
        FROM VendorPart vp2
        JOIN Part p2 ON vp2.PartID = p2.PartID
        WHERE p2.PartType = 'Cup'
          AND p2.Weight < 4
    );


select * from person;

