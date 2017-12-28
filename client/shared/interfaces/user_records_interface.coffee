BaseRecordsInterface = require 'shared/record_store/base_records_interface.coffee'
UserModel            = require 'shared/models/user_model.coffee'

_ = require 'lodash'

module.exports = class UserRecordsInterface extends BaseRecordsInterface
  model: UserModel

  updateProfile: (user) =>
    @remote.post 'update_profile', _.merge(user.serialize(), {unsubscribe_token: user.unsubscribeToken })

  uploadAvatar: (file) =>
    @remote.upload 'upload_avatar', file

  changePassword: (user) =>
    @remote.post 'change_password', user.serialize()

  deactivate: (user) =>
    @remote.post 'deactivate', user.serialize()

  saveExperience: (experience) =>
    @remote.post 'save_experience', experience: experience

  emailStatus: (email) ->
    @fetch
      path: 'email_status'
      params: {email: email}
