# Contributing

## dependencies
tools used:
- make
- git
- [asdf version manager](https://asdf-vm.com/guide/getting-started.html)

## first run ...

### install project tools
use asdf to ensure required tools are installed ... configured tools are in  [.tool-versions](.tool-versions)
```bash
cd ~/work/terraform-aws-backup
for plugin in $(grep -E '^\w+' .tool-versions | cut -d' ' -f1); do asdf plugin add $plugin; done
asdf install
```

### setup git-secrets
git secrets scanning uses the awslabs https://github.com/awslabs/git-secrets there are options on how to install but
```bash
# if the command `git secrets` does not work in your repo
# the git-secrets script needs to be added to somewhere in your PATH
# for example if $HOME/.local/bin is in your PATH environment variable
# then:
wget https://raw.githubusercontent.com/awslabs/git-secrets/refs/heads/master/git-secrets -O ~/.local/bin/git-secrets
chmod +x ~/.local/bin/git-secrets
```

### install pre-commit hooks
```shell
pre-commit install
```


### secrets
the git-secrets script will try and avoid accidental committing of secrets
patterns are excluded using  [.gitdisallowed](.gitdisallowed) and allow listed using  [.gitallowed](.gitallowed)
You can check for secrets / test patterns at any time though with
```shell
make check-secrets-all
```
