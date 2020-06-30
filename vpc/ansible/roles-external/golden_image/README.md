# ansible-golden_image

Role used on ubuntu base AMIs on AWS.

## How to download this role

Add the following to a `requirements.yml` file:

```yml
- src: git+https://github.com/wireapp/ansible-golden_image.git
  name: golden_image
  version: v0.1.0
```

Then run ansible-galaxy install -r requirements.yml

## For maintainers

Push tags on changes:

```
git tag v0.1.0
git push --tags
```
