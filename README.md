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

The `docker_deploy_git_repositories` can be use

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
            docker_deploy_docker_compose_template: "path_to/docker-compose.yml"
```

Example 2:
```
- hosts: servers
  roles:
      - role: ansible-docker-deploy
        vars: 
          docker_deploy_docker_compose_template: "path_to/docker-compose.yml"
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
    docker_deploy_docker_compose_template: "path_to/docker-compose.yml"
    docker_compose_git_repositories:
    - repo: https://github.com/fccn/wp-nau-theme.git
      dest: "{{ wordpress_nau_theme_dest }}"
      version: "{{ wordpress_nau_theme_version | default('master') }}"
      force: true
      owner: www-data
      group: www-data
      mode: u=rwX,g=rX,o=rX
      fact: wordpress_nau_theme_git_version
```
   
playbook
```
    hosts: servers
    roles:
        - ansible-docker-deploy
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
