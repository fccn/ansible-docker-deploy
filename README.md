Ansible Docker Deploy
=========

Ansible utility role to easilly deploy a docker compose or stack. It copies, templates and git clones a repository and then deploys the software using docker compose. This role doesn't install docker or compose or stack, it's only focus is the deployment process.

Requirements
------------

Only ansible.

Compatible with ansible 2.7 (only docker-compose) and 2.9.

Role Variables
--------------

The `docker_deploy_base_folder` optional variable is the destination of the docker-compose.yml file. The ideia is to be the base directory where everything goes to the target machine.
The optional list variables can be used to copy, template or git clone a list of those assets using the variables:
* `docker_deploy_files` - copy files
* `docker_deploy_templates` - list of templates
* `docker_deploy_git_repositories` - to clone a list of repositories

You can get the git version of the git of each `docker_deploy_git_repositories` by adding an attribute `fact` so the role define a new fact that could be used within the templates or within the compose.
You can use a specific ssh key to clone the git repository if you define a `ssh_key`

This role can deploy a docker compose to the ansible target server or a docker stack to a docker swarm. 
For that you need to define one of the following variables:
* `docker_deploy_compose_template` - deploy a docker compose to the target ansible server
* `docker_deploy_stack_template` - deploy a docker stack to the docker swarm

If you define `docker_deploy_compose_template` variable, the role by default would use the ansible 
role `docker_service`. But because ansible only supports the docker-compose '2' specification, this
role has an additional option that use the `docker-compose up` command directly. 
So if you need to use the docker-compose syntax > 2.0, you need to assign `true` to the variable 
`docker_deploy_shell`.

* `docker_deploy_shell_start_default` - by default uses the command 
`docker-compose pull && docker-compose build && docker-compose up -d` that pull's, build's and 
startup the compose. By default a `--force-recreate` parameter is added if any file, template or git 
repository has changed. You can replace that additional parameter if you override the 
`docker_deploy_shell_start_default_additional_parameters` ansible variable.

* `docker_deploy_force_restart` - to forcelly restart / recreate the containers

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

Example 4:

group vars
```
    docker_deploy_stack_template: "path_to/docker-stack.yml"
    docker_deploy_stack_name: wordpress
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
* https://educast.fccn.pt
