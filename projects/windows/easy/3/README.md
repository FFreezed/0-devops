# AD DS Task 3: Centralized Shared Folders, NTFS vs. Share Permissions, and Access-Based Enumeration (ABE)

Difficulty: 🟢 Easy

Primary Tools: Windows Server 2022/2025, Windows 10/11, File and Storage Services, Active Directory Users and Computers (ADUC), Group Policy Management Console (GPMC), PowerShell

Time to Complete: 2 hours

---

## 🏢 Scenario & Architectural Design

In any company running Active Directory, central file storage is a core requirement. However, simply sharing a folder on a network drive can easily lead to security breaches if permissions are configured incorrectly.

Enterprise System Administrators use a gold-standard model called **AGDLP** (Account → Global Group → Domain Local Group → Permission). They also combine two layers of security: **SMB Share Permissions** and **NTFS File Permissions**, alongside a feature called **Access-Based Enumeration (ABE)**—which hides files and folders from users if they don't have read access to them.

In this lab, you will set up a centralized File Share on `DC-01` (or a dedicated server), configure group-based permissions using AD Security Groups, automatically map the drive to client PCs using a GPO, and test Access-Based Enumeration to ensure users only see what they are authorized to see.

---

## 📐 Logical Architecture Diagram (ASCII format)

```text
┌──────────────────────────────────────────────────────────────────────────┐
│ DC-01 (File Server) - C:\Shares\CompanyData                              │
│                                                                          │
│  ├── 📁 HR-Private                                                       │
│  │    └── Permissions: Read/Write -> DL-HR-RW (Contains SG-HR-Staff)     │
│  │                                                                       │
│  └── 📁 IT-Private                                                       │
│       └── Permissions: Read/Write -> DL-IT-RW (Contains SG-IT-Staff)     │
│                                                                          │
│  [ Shared as: \\DC-01\CompanyData$ ]                                     │
│  [ Feature Enabled: Access-Based Enumeration (ABE) ]                     │
└──────────────────────────────────────────────────────────────────────────┘
                                   ▲
                                   │ Automatically Mapped via GPO (Drive Z:)
                                   │
┌──────────────────────────────────┴───────────────────────────────────────┐
│ CLIENT-01 (Win 10/11)                                                    │
│                                                                          │
│  • Logged in as: jsmith (Member of IT)                                   │
│  • Drive Z:\ contains ONLY 📁 IT-Private                                 │
│  • 📁 HR-Private is INVISIBLE (Hidden by Access-Based Enumeration)        │
└──────────────────────────────────────────────────────────────────────────┘

```

---

## 🛠️ The Implementation Requirements

### 1. Group Strategy Setup (ADUC)

1. On `DC-01`, open **Active Directory Users and Computers** (`dsa.msc`).
2. Inside `CORP-Company`, create a new OU named `HR-Department`.
3. Create a user inside `HR-Department` named **Alice Vance** (`avance`).
4. Create a Global Security Group inside `HR-Department` named `SG-HR-Staff` and add `avance` to it.
5. Create two **Domain Local Security Groups** inside an OU of your choice (e.g., inside a new `Groups` OU):
* `DL-IT-Share-RW` (Domain Local group for IT Read/Write access)
* `DL-HR-Share-RW` (Domain Local group for HR Read/Write access)


6. Add `SG-IT-Staff` as a member of `DL-IT-Share-RW`.
7. Add `SG-HR-Staff` as a member of `DL-HR-Share-RW`.

---

### 2. File Share, NTFS, and Access-Based Enumeration (ABE) Setup

1. On `DC-01`, create a folder path: `C:\Shares\CompanyData`.
2. Inside `CompanyData`, create two subfolders:
* `IT-Private`
* `HR-Private`


3. Right-click `CompanyData` -> **Properties** -> **Sharing** -> **Advanced Sharing**:
* Share the folder as `CompanyData$` *(Adding `$` makes it a hidden share).*
* Set **Share Permissions** to: `Everyone = Full Control` *(We will handle security using NTFS permissions).*


4. Configure **NTFS Permissions** on the subfolders (Properties -> Security -> Advanced):
* **Disable Inheritance** on both `IT-Private` and `HR-Private` (convert inherited permissions to explicit permissions, then remove the default `Users` group).
* On `IT-Private`: Grant `DL-IT-Share-RW` **Modify** permissions.
* On `HR-Private`: Grant `DL-HR-Share-RW` **Modify** permissions.


5. **Enable Access-Based Enumeration (ABE):**
* Open **Server Manager** -> **File and Storage Services** -> **Shares**.
* Right-click `CompanyData$` -> **Properties** -> **Settings**.
* Check **Enable access-based enumeration**.



---

### 3. Automatically Mapping the Network Drive via GPO

1. Open **Group Policy Management** (`gpmc.msc`) on `DC-01`.
2. Create and link a new GPO to the `CORP-Company` OU named `GPO_Map_Network_Drives`.
3. Edit the GPO and navigate to:
* `User Configuration -> Preferences -> Windows Settings -> Drive Maps`


4. Right-click **Drive Maps** -> **New** -> **Mapped Drive**:
* **Action:** Update
* **Location:** `\\DC-01\CompanyData$`
* **Reconnect:** Enabled
* **Drive Letter:** `Z:`
* **Label:** `Company Data`



---

## 🚨 Operational Troubleshooting Inject (Live Fire Exercise)

### Failure Scenario

You log into `CLIENT-01` as `corp\jsmith` (IT user). Drive `Z:` appears, but when clicking into `Z:\`, `jsmith` can see **both** `IT-Private` and `HR-Private` folders, even though `jsmith` is not in the HR group! Furthermore, when double-clicking `HR-Private`, an error states *"Access Denied"*.

### Debugging Actions & Commands

1. On `DC-01`, open **Server Manager** -> **File and Storage Services** -> **Shares**.
2. Verify that **Access-Based Enumeration (ABE)** is actually checked on `CompanyData$`.
3. Check the NTFS permissions on `C:\Shares\CompanyData\HR-Private`.

### Root Cause Hint

Access-Based Enumeration (ABE) hides folders *only* if the user does not have `Read` or `List Folder Contents` permissions on that specific folder. If the parent folder's inherited permissions (or the default `Authenticated Users` / `Domain Users` groups) were left on the `HR-Private` folder, Windows thinks `jsmith` still has "Read" rights to list the folder name, even if they can't open it. You must explicitly remove `Domain Users` or `Users` from the NTFS Security tab of the subfolders!

---

## ✅ Acceptance Criteria & Proof of Success

1. **Drive Mapping Test:** Log into `CLIENT-01` as `corp\jsmith`. Open File Explorer. Drive `Z:` (`\\DC-01\CompanyData$`) should automatically appear under "This PC".
2. **Access-Based Enumeration (ABE) Test (IT User):** Inside Drive `Z:`, `jsmith` should **only** see the `IT-Private` folder. `HR-Private` must be completely invisible.
3. **Access-Based Enumeration (ABE) Test (HR User):** Log out and log into `CLIENT-01` as `corp\avance` (HR user). Open Drive `Z:`. `avance` should **only** see the `HR-Private` folder. `IT-Private` must be completely invisible.