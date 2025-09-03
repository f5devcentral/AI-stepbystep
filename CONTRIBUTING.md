# Contributing Guide

Thank you for your interest in contributing to this project! This guide will help you get started with the Git workflow and development process.

## Getting Started

### 1. Fork the Repository

Fork this repository to your GitHub account by clicking the "Fork" button at the top of the repository page.

### 2. Clone Your Fork

Clone the project to your local development machine:

```bash
git clone https://github.com/<your-username>/<repository-name>.git
```

*Replace `<your-username>` with your GitHub username and `<repository-name>` with the actual repository name.*

### 3. Configure Upstream Remote

Configure your fork to sync with the original repository:

```bash
git remote add upstream https://github.com/f5devcentral/AI-stepbystep

# Verify the configuration
git remote -v
```

You should see output similar to:
```
origin    https://github.com/<your-username>/<repository-name>.git (fetch)
origin    https://github.com/<your-username>/<repository-name>.git (push)
upstream  https://github.com/f5devcentral/AI-stepbystep (fetch)
upstream  https://github.com/f5devcentral/AI-stepbystep (push)
```

## Development Workflow

### 4. Create a Feature Branch

Always create a new branch for your work:

```bash
# Switch to main branch and sync with upstream
git checkout main
git fetch upstream
git rebase upstream/main

# Create and switch to your new feature branch
git checkout -b feature/your-feature-name
```

Use descriptive branch names like:
- `feature/add-new-component`
- `bugfix/fix-login-issue`
- `docs/update-readme`

### 5. Make Your Changes

Make your changes and commit them with meaningful messages:

```bash
# Add files to staging
git add <file1> <file2>

# Or add all changes
git add .

# Commit with a meaningful message
git commit -m "Add feature: brief description of what you did"
```

**Commit Message Guidelines:**
- First line should be a concise summary (50 characters or less)
- Use present tense ("Add feature" not "Added feature")
- Include more details in subsequent lines if necessary

### 6. Stay Up to Date

Before pushing your changes, sync with the upstream repository:

```bash
git fetch upstream
git rebase upstream/main
```

If there are conflicts, resolve them following the steps in the [Troubleshooting](#troubleshooting) section.

### 7. Push Your Changes

Push your branch to your fork:

```bash
git push origin your-branch-name
```

### 8. Create a Pull Request

1. Go to your fork on GitHub
2. Click "New Pull Request"
3. Select your branch and provide a clear description of your changes
4. Request review from the maintainers

## Code Review Process

- Maintainers will review your pull request
- Address any feedback by making additional commits to your branch
- Once approved, a maintainer will merge your changes

## Best Practices

### Branch Management

- Keep your main branch clean and always sync it with upstream before creating new branches:

```bash
git fetch upstream
git rebase upstream/main main
git checkout main
git checkout -b new-feature-branch
```

### Working with Stash

If you need to switch branches but aren't ready to commit:

```bash
# Save current work
git stash save "descriptive message about your changes"

# Switch to other branch
git checkout other-branch

# Later, return to your branch
git checkout original-branch

# See available stashes
git stash list

# Apply your stashed changes
git stash apply stash@{0}
```

### Building on Unmerged Features

If you need features from another branch that hasn't been merged yet:

```bash
# Base your new branch on the prerequisite branch
git fetch upstream
git rebase upstream/main prerequisite-branch
git checkout prerequisite-branch
git checkout -b new-branch
```

## Troubleshooting

### Testing Pull Requests

Add this alias to your `~/.gitconfig` to easily test pull requests:

```ini
[alias]
    copr = !sh -c 'git fetch upstream pull/$1/head:pr-$1 && git checkout pr-$1' --
```

Then use: `git copr <pr-number>`

### Resolving Merge Conflicts

When rebasing creates conflicts:

1. Check status: `git status`
2. Edit conflicted files to resolve conflicts
3. Add resolved files: `git add <file>`
4. Continue rebase: `git rebase --continue`
5. Repeat until all conflicts are resolved

### Other Useful Commands

**Pull changes from a specific branch:**
```bash
git pull origin <branch-name>
```

**Checkout a remote branch locally:**
```bash
git checkout -b <local-branch-name> <remote-name>/<remote-branch-name>
```

**Reset to a specific commit (⚠️ use with caution):**
```bash
git reset --hard <commit-hash>
```

**Squash commits before pull request:**
```bash
# Check your commits
git log HEAD~<number-of-commits>..HEAD

# Interactive rebase
git rebase -i HEAD~<number-of-commits>
```

In the editor, change `pick` to `squash` for commits you want to combine.

**Delete branches after merge:**
```bash
# Delete local branch
git branch -d <branch-name>

# Delete remote branch
git push origin -d <branch-name>
```

**Clone into existing directory:**
```bash
git clone https://github.com/user/repo.git temp
mv temp/.git existing-directory/.git
rm -rf temp
```

## Getting Help

- Check existing issues before creating new ones
- Use clear, descriptive titles for issues and pull requests
- Provide as much relevant information as possible
- Be patient and respectful in all interactions

Thank you for contributing! 🎉
