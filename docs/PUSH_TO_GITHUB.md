# How to Push to GitHub

Your repository is set up and ready to push! Here are the steps:

## Option 1: Using Personal Access Token (Recommended)

1. **Create a Personal Access Token on GitHub:**

   - Go to: https://github.com/settings/tokens
   - Click "Generate new token" → "Generate new token (classic)"
   - Give it a name (e.g., "glanz-rental-app")
   - Select scopes: Check `repo` (full control of private repositories)
   - Click "Generate token"
   - **Copy the token** (you won't see it again!)

2. **Push using the token:**
   ```bash
   git push -u origin main
   ```
   When prompted:
   - Username: `cbabi2023`
   - Password: Paste your Personal Access Token (not your GitHub password)

## Option 2: Using SSH (More Secure)

1. **Check if you have SSH keys:**

   ```bash
   ls -la ~/.ssh
   ```

2. **If no SSH keys exist, generate one:**

   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```

   Press Enter to accept defaults, optionally add a passphrase.

3. **Add SSH key to GitHub:**

   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```

   Copy the output, then:

   - Go to: https://github.com/settings/keys
   - Click "New SSH key"
   - Paste the key and save

4. **Change remote to SSH:**

   ```bash
   git remote set-url origin git@github.com:cbabi2023/glanz_rental_app.git
   ```

5. **Push:**
   ```bash
   git push -u origin main
   ```

## Option 3: Using GitHub CLI

1. **Install GitHub CLI** (if not installed)
2. **Authenticate:**
   ```bash
   gh auth login
   ```
3. **Push:**
   ```bash
   git push -u origin main
   ```

---

## Quick Push Command

Once authenticated, run:

```bash
git push -u origin main
```
