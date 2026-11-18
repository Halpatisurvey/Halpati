# Halpati Baseline Survey – Complete guide (offline app + Supabase server)

HOW IT WORKS
- Surveyors fill the form on their phone, with or without internet. Entries + photos are saved on the phone first.
- When the phone gets internet (evening), entries and photos go to your Supabase server by themselves. 1.5 lakh+ entries are no problem for the server.
- You see everything on the admin page (admin.html) and download Excel from there (filter by taluka / surveyor / date).
- The phone Excel button still exists, but only as a backup.

Do NOT double-click `sw.js`, `config.js` or `index.html` on a computer. Only upload them as shown below.


==============================================================
BOTH WAYS - how nothing is ever lost (read this)
==============================================================
Every entry is kept in 3 places:
 1. On the phone (until you choose to remove photos).
 2. On the Supabase server (automatic when internet is available)  -> shown as  ☁✔
 3. In an Excel file with photos that the surveyor downloads daily  -> shown as  📄✔
In the "સાચવેલી" tab each entry shows both marks (☁ and 📄). ⏳ means not yet done.

Rules for surveyors:
- Every evening: Excel tab -> Download Excel file -> send it to the coordinator (WhatsApp / email). The app also reminds after every 20 entries.
- Every evening: Excel tab -> "📅 તારીખ પ્રમાણે Excel" list -> press the download button of that date (e.g. 17/11/2026 gives only that day's entries, 18/11/2026 gives only that day's). Send each file to the coordinator. A date shows 📄✔ once downloaded. If you add or edit an entry later on that date, it shows ⏳ again - download that date again.
- There is NO delete button and NO remove-photo button. The app never deletes anything.
- If a phone is lost / broken: login on a new phone with the same ID, Excel tab -> "Restore from an Excel file" (choose the surveyor's last Excel). Entries and photos come back and sync again WITHOUT making duplicates.

Rules for you (admin):
- Keep every Excel file the surveyors send in one folder (and a copy on Google Drive).
- Once a week download a full Excel from the admin page and save it too.
- Supabase -> Project Settings -> Add-ons / Database -> Backups: use the paid plan so daily backups are on.
- Coordinator can also combine surveyors' Excel files: Excel tab -> "Combine files into one master workbook".

==============================================================
STEP 1 – Supabase database (you already have the project)
==============================================================
1. Open https://supabase.com/dashboard/project/mudckxqpmkqzablcrvhd
2. Left menu -> **SQL Editor** -> **New query**.
3. Open `supabase_setup.sql` from this folder in Notepad, Select All (Ctrl+A), Copy.
4. Paste in the SQL Editor, click **Run**. It must say "Success". (If you ran an older version before, the last line adds the new column - safe to run again.)
5. Left menu -> **Authentication** -> **Providers** (or Sign In / Providers) -> **Email** -> turn **"Confirm email" OFF** -> Save.

==============================================================
STEP 2 – Create your ADMIN login
==============================================================
1. **Authentication -> Users -> Add user -> Create new user**
   - Email: `admin@halpati.survey`
   - Password: choose one (write it down)
   - Tick **Auto Confirm User** -> Create.
2. **SQL Editor -> New query**, paste and Run (put your name instead of Dhairya):
```
insert into public.surveyors (user_id, code, name, is_admin)
select id, 'ADMIN', 'Dhairya', true from auth.users where email = 'admin@halpati.survey';
```

==============================================================
STEP 3 – Create SURVEYOR logins (repeat for every surveyor)
==============================================================
1. Authentication -> Users -> Add user: email `s001@halpati.survey`, a password, tick Auto Confirm.
2. SQL Editor, Run (change S001, name and email each time):
```
insert into public.surveyors (user_id, code, name, is_admin)
select id, 'S001', 'Ramesh Patel', false from auth.users where email = 's001@halpati.survey';
```
The surveyor logs in only with `S001` and the password (the @halpati.survey part is added by the app).
The code (S001) becomes part of every Survey ID, so IDs never repeat between surveyors.

==============================================================
STEP 4 – Put your Supabase key in config.js
==============================================================
1. Supabase -> **Project Settings -> API Keys** -> copy the **anon / public** key (long text starting with `eyJ`). NEVER use "service_role".
2. Right-click `config.js` -> Open with -> **Notepad**.
3. Replace `PASTE-YOUR-ANON-PUBLIC-KEY-HERE` with the key (keep the quote marks "  "). Save.
   (The URL is already filled with your project.)

==============================================================
STEP 5 – Put the app online (GitHub Pages)
==============================================================
1. github.com -> **+ -> New repository** -> name `halpati` -> Public -> Create.
2. Click **uploading an existing file**. Drag ALL files of this folder (index.html, admin.html, config.js, sw.js, manifest.json, xlsx.min.js, both icons, the .xlsx, the .sql) into it -> **Commit changes**.
3. **Settings -> Pages** -> Branch **main**, folder **/(root)** -> Save. After 1-2 minutes you get your link:
   - Surveyors: `https://YOUR-NAME.github.io/halpati/`
   - Admin:     `https://YOUR-NAME.github.io/halpati/admin.html`

==============================================================
STEP 6 – Install on each surveyor phone
==============================================================
1. Open the surveyor link in **Chrome** (with internet), not inside WhatsApp.
2. Tap **લૉગિન** in the green bar -> enter ID (S001) and password -> login. Their name is filled in automatically.
3. Chrome menu ⋮ -> **Add to Home screen**. Allow Location and Camera.
4. Turn internet OFF and open the app from the home screen - it must open. That is your offline test.

==============================================================
STEP 7 – Daily work (surveyor)
==============================================================
1. Fill the form, take document photos (📷) or upload (📁), tap **એન્ટ્રી સાચવો**.
2. When internet arrives the bar shows "☁ ... સર્વર પર · ⏳ 0 બાકી". Nothing else to do. Press **☁ સિંક** to force it.
3. Every evening: Excel tab -> download the Excel of today's date (and of any date still showing 📄⏳).
4. Never clear Chrome data while the bar shows ⏳ pending entries.

==============================================================
STEP 8 – You: admin dashboard + Excel
==============================================================
1. Open the admin link, login `admin` + your password.
2. You see totals, today's count, daily chart, per surveyor, per taluka, jati, house type, income source.
3. **Excel ડાઉનલોડ**: choose district / taluka / surveyor / dates (or none for all) -> download. Files above 40,000 rows come in parts (part1, part2...). Open them in Excel and use Pivot / Filter for analysis.
4. **ડુપ્લિકેટ મોબાઈલ** downloads entries that share a mobile number.
5. **નોંધ શોધો**: search by name / mobile / survey ID and open all photos of that entry.

==============================================================
STEP 9 – Village names (DONE - already inside the app)
==============================================================
Your list (3,490 villages, 8 districts, 57 talukas) is built into index.html. Nothing to import.
Names are in English exactly as in your Excel (ALL CAPS changed to Capital Letters). 2 repeated names in the same taluka were merged.
Surat city areas (Adajan, Katargam, Majura, Puna, Udhana) are shown together under "સુરત સિટી". "પલસાણા" taluka was added.
If a village is missing, surveyors choose "➕ યાદીમાં નથી" and type it.

==============================================================
Updating the app later
==============================================================
Upload the new index.html on GitHub (replace), and in `sw.js` change `halpati-v3` to `halpati-v4` (then v5 ...). Phones update when opened with internet.

PRIVACY: Aadhaar / ration card photos are private on the server - only logged-in surveyors (their own entries) and admin can see them. Keep the admin password safe, never share the service_role key.
