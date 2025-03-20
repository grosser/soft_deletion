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

# get soft deleted records
User.soft_deleted
```

To add the `deleted_at` to your model, you can either generate a migration using:

```
rails generate migration add_deleted_at_to_users deleted_at:datetime:index
```

or create a migration file yourself like:

```Ruby
class AddDeletedAtToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :deleted_at, :datetime
    add_index :users, :deleted_at
  end
end
```

By default `soft_deletion` does not change the `updated_at` value in the record. If you need this feature, you can use the `update_timestamp` option:

```Ruby
require 'soft_deletion'

class User < ActiveRecord::Base
  has_soft_deletion update_timestamp: true
end
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
 - [Yaroslav](https://github.com/viralpraxis)

[Zendesk](http://zendesk.com)<br/>
michael@grosser.it<br/>
License: MIT<br/>
![CI](https://github.com/grosser/soft_deletion/workflows/CI/badge.svg)
