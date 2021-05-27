Ansible Docker Deploy
=========

Ansible utility role to easilly deploy a docker compose or stack. It copies, templates and git clones a repository and then deploys the software using docker compose or stack. This role doesn't install docker, compose or stack, it's only focus is the deployment process.

Requirements
------------

Only ansible.

Role Variables
--------------

The `docker_deploy_base_folder` optional variable is the destination of the docker-compose.yml file. The ideia is to be the base directory where everything goes to the target machine.
The optional list variables can be used to copy, template or git clone a list of those assets using the variables:
* `docker_deploy_files` - copy files
* `docker_deploy_templates` - list of templates
* `docker_deploy_git_repositories` - to clone a list of repositories

You can get the git version of the git of each `docker_deploy_git_repositories` by adding an attribute `fact` so the role define a new fact that could be used within the templates or within the compose.
You can use a specific ssh key to clone the git repository if you define a `ssh_key`

Dependencies
------------

Any. Only ansible.

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

Example 1:
```
  - hosts: servers
    roles:
        - role: ansible-docker-deploy
          vars: 
            docker_deploy_compose_template: "path_to/docker-compose.yml"
```

Example 2:
```
- hosts: servers
  roles:
      - role: ansible-docker-deploy
        vars: 
          docker_deploy_compose_template: "path_to/docker-compose.yml"
          docker_deploy_files:
            - src: "local_path/cert.key.pem"
              dest: "{{ docker_deploy_base_folder }}/cert.key.pem"
          docker_deploy_templates:
            - src: "local_path/nginx.conf"
              dest: "{{ docker_deploy_base_folder }}/nginx.conf"
            - src: "local_path/Makefile"
              dest: "{{ docker_deploy_base_folder }}/Makefile"
  ```
  
Example 3:

group vars
```
    docker_deploy_compose_template: "path_to/docker-compose.yml"
    docker_deploy_git_repositories:
    - repo: https://github.com/fccn/wp-nau-theme.git
      dest: "{{ wordpress_nau_theme_dest }}"
      version: "{{ wordpress_nau_theme_version | default('master') }}"
      force: true
      owner: www-data
      group: www-data
      mode: u=rwX,g=rX,o=rX
      fact: wordpress_nau_theme_git_version
      # ssh_key: "{{ SSH_KEY_CONTENT }}"
```
   
playbook
```
    hosts: servers
    roles:
        - ansible-docker-deploy
```

Test this role
-------

To test the syntax run:
```
virtualenv venv
. venv/bin/activate
pip install ansible==2.7.12
printf '[defaults]\nroles_path=../' >ansible.cfg
ansible-playbook tests/test.yml -i tests/inventory --syntax-check
```

License
-------

GPLv3

Author Information
------------------

Ivo Branco <ivo.branco@fccn.pt>
* https://www.fccn.pt
* https://arquivo.pt
* https://www.nau.edu.pt
* https://portal.educast.fccn.pt/
