# Ansible Docker Deploy


Ansible utility role to easily deploy a docker compose or stack. It copies, templates and git clones a repository and then deploys the software using docker compose/stack. Additionally waits for containers to become healthy.

This role doesn't install docker, docker compose or docker stack. The focus is the deployment of containers.

## Requirements


Only ansible.

Compatible with ansible 2.7 (only docker-compose) and 2.9.

## Role Variables


The `docker_deploy_base_folder` variable is the destination of the docker-compose.yml or docker-stack.yml file. 
The idea is to be the base directory where everything goes to the target machine.

Variables that can be used to copy, template or git clone a list of those assets using the variables:
* `docker_deploy_files` - copy files, default value `[]`;
* `docker_deploy_templates` - list of templates, default value `[]`;
* `docker_deploy_git_repositories` - to clone a list of repositories, default value `[]`;

You can get the git version of the git of each `docker_deploy_git_repositories` by adding an attribute `fact` so the role define a new fact that could be used within the templates or within the compose.
You can use a specific ssh key to clone the git repository if you define a `ssh_key`

This role can deploy a docker compose to the ansible target server or a docker stack to a docker swarm. 

The next 2 variables decide the mode of the deploy, or a compose or a stack::
* `docker_deploy_compose_template` - deploy a docker compose to the target ansible server
* `docker_deploy_stack_template` - deploy a docker stack to the docker swarm

### Compose mode

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

* `docker_deploy_force_restart` - to forcefully restart / recreate the containers

### Stack mode

To execute this ansible role using the docker stack mode, you need to defined the variable:
* `docker_deploy_stack_template` - the file to be templated that contains the docker stack definition.

Optional parameter:
* `docker_deploy_stack_name` - the name of the stack, by default uses the basename of the folder defined in the `docker_deploy_base_folder` variable.

## Advanced parameters

Each template defined in `docker_deploy_templates` or file defined in `docker_deploy_files` can have a attribute `config_name` and/or `secret_name` that makes this ansible role to create a docker config or a docker secret.

Because the docker config and secrets are idempotent, you can't easily update them. The solution documented in multiple forums is to suffix each config/secret with a checksum. This ansible role make this pattern more easily by defining an ansible fact (variable) to each templated / copied docker config or secret.
Example:
* `docker_deploy_config_<stack name or basename of the base folder>_<config_name>`
* `docker_deploy_secret_<stack name or basename of the base folder>_<secret_name>`


```yml
...
    configs:
      - source: my_config_name_{{ hostvars[inventory_hostname]['docker_deploy_config_' + docker_deploy_stack_name + '_' + 'my_config_name' ][:10] }}
        target: /etc/mysql/conf.d/mysql.cnf
...
configs:
{% for template in ( docker_deploy_templates | selectattr('config_name', 'defined') | list ) %}
  my_config_name_{{ hostvars[inventory_hostname]['docker_deploy_config_' + docker_deploy_stack_name + '_' + 'my_config_name' ][:10] }}:
    file: {{ template.dest }}
{% endfor %}
...
```

## Dependencies

Any. Only ansible.

## Example Playbook

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

Example 1:
```yml
  - hosts: servers
    roles:
        - role: ansible-docker-deploy
          vars: 
            docker_deploy_compose_template: "path_to/docker-compose.yml"
```

Example 2:
```yml
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
```yml
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
```yml
    hosts: servers
    roles:
        - ansible-docker-deploy
```

Example 4:

group vars
```yml
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
```yml
    hosts: servers
    roles:
        - ansible-docker-deploy
```


## Test this role

To test the syntax run:
```bash
virtualenv venv
. venv/bin/activate
pip install ansible==2.7.12
printf '[defaults]\nroles_path=../' >ansible.cfg
ansible-playbook tests/test.yml -i tests/inventory --syntax-check
```

## License

GPLv3

Author Information
------------------

Ivo Branco <ivo.branco@fccn.pt>
* https://www.fccn.pt
* https://arquivo.pt
* https://www.nau.edu.pt
* https://educast.fccn.pt
