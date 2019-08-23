Explicit soft deletion for ActiveRecord via deleted_at + callbacks and optional default scope.<br/>
Not overwriting destroy or delete.

Install
=======

```Bash
gem install soft_deletion
```

Usage
=====

```Ruby
require 'soft_deletion'

class User < ActiveRecord::Base
  has_soft_deletion default_scope: true

  before_soft_delete :validate_deletability # soft_delete stops if this returns false
  after_soft_delete :send_deletion_emails

  has_many :products
end

# soft delete them including all soft-deletable dependencies that are marked as :destroy, :delete_all, :nullify
user = User.first
user.products.count == 10
user.soft_delete!(validate: false)
user.deleted? # true

# use special with_deleted scope to find them ...
user.reload # ActiveRecord::RecordNotFound
User.with_deleted do
  user.reload # there it is ...
  user.products.count == 0
end

# Do NOT use on assocations: Account.first.users.with_deleted {

# soft undelete them all
user.soft_undelete!
user.products.count == 10

# soft delete many
User.soft_delete_all!(1,2,3,4)
```

TODO
====
 - has_many :through should delete join associations on soft_delete
 - cascading soft_deletes should use the same timestamp for easy reverts

Authors
=======

### [Contributors](https://github.com/grosser/soft_deletion/contributors)
 - [Michel Pigassou](https://github.com/Dagnan)
 - [Steven Davidovitz](https://github.com/steved555)
 - [PikachuEXE](https://github.com/PikachuEXE)
 - [Noel Dellofano](https://github.com/pinkvelociraptor)
 - [Oliver Nightingale](https://github.com/olivernn)
 - [Kumar Pandya](https://github.com/kpandya91)
 - [Alex Pauly](https://github.com/apauly)

[Zendesk](http://zendesk.com)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/soft_deletion.png)](https://travis-ci.org/grosser/soft_deletion)
