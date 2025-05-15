# XYZ Database Project

## EER Diagram
![SemProjER drawio (1)](https://github.com/user-attachments/assets/5894f6bf-cbb5-4d4f-84a3-aa25de621b0b)

## Dependency Diagram
![DB drawio](https://github.com/user-attachments/assets/cdfb030e-e035-49be-bdf0-9d07ea513969)

## Logical Diagram
![logical diagram](https://github.com/user-attachments/assets/43c222e4-69b0-4f0f-9f38-2c80c8b71a75)

## Database Viewer
### Tables
![image](https://github.com/user-attachments/assets/b0f39324-16af-413f-a1f4-c7e6c3ecbbf5)

### Custom Queries
![image](https://github.com/user-attachments/assets/f52ffc33-bbc5-4f6b-98c9-4d5a6ce76d49)

#### Premade Queries
```sql
--1 Hellen Cole (job=11111)
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
```
```sql
-- 2 id of jobs posted by marketing
SELECT
    jp.JobID
FROM
    JobPosition jp
    JOIN Department d ON jp.DepartmentID = d.DepartmentID
WHERE
    d.DepartmentName = 'Marketing'
    AND jp.PostedDate BETWEEN '2011-01-01' AND '2011-01-31';
```
```sql
-- 3 id and name of employeees without supervisees
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
```
```sql
-- 4 marketing sites without sales in March 2011
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
```
```sql
-- 5 job id and description of jobs which haven't had a suitable hire a month after it's posted
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
```
```sql
-- 6  id and name of salesmen who of sold all product type whose price is above $200
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
```
```sql
-- 7 department id and name which has no job post during 1/1/2011 and 2/1/2011
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
```
```sql
-- 8 ID, Name, Department ID of employees who applied for job "12345"
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
```
```sql
-- 9 best seller's type in the company
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
```
```sql
-- 10 product type whose net profit is highest
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
```
```sql
-- 11 name and id of employees who have worked in all departments after hired by the company
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
```
```sql
-- 12 name and email of interviewee who is selected
SELECT DISTINCT
    p.FirstName,
    p.LastName,
    p.Email
FROM
    JobApplication ja
    JOIN Person p ON ja.ApplicantID = p.PersonalID
WHERE
    ja.Status = 'Hired';
```
```sql
-- 13 name, phone number, email of interviewees selected for all jobs they applied for 
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
```
```sql
-- 15 name and id of vendor who supplies the "cup" with wieght smaller than 4lbs and the price is lowest among all vendors
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
```
