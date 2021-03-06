<script lang="coffee">
import Session        from '@/shared/services/session'
import AbilityService from '@/shared/services/ability_service'
import { map, sortBy, filter } from 'lodash'
import AppConfig from '@/shared/services/app_config'
import Records from '@/shared/services/records'
import EventBus from '@/shared/services/event_bus'
import Flash   from '@/shared/services/flash'
import { onError } from '@/shared/helpers/form'

export default
  props:
    discussion: Object
    close: Function
    isPage: Boolean

  data: ->
    upgradeUrl: AppConfig.baseUrl + 'upgrade'
    availableGroups: []
    submitIsDisabled: false

  mounted: ->
    @watchRecords
      collections: ['groups', 'memberships']
      query: (store) =>
        @availableGroups = filter(Session.user().groups(), (group) -> AbilityService.canStartThread(group))

  methods:
    submit: ->
      actionName = if @discussion.isNew() then 'created' else 'updated'
      @discussion.save()
      .then (data) =>
        discussionKey = data.discussions[0].key
        Records.discussions.findOrFetchById(discussionKey, {}, true).then (discussion) =>
          Flash.success("discussion_form.messages.#{actionName}")
          @$router.push @urlFor(discussion)
          if @discussion.isNew()
            if AbilityService.canAnnounceTo(discussion)
              EventBus.$emit 'openModal',
                component: 'AnnouncementForm',
                props:
                  announcement: Records.announcements.buildFromModel(discussion)
      .catch onError(@discussion)


    updatePrivacy: ->
      @discussion.private = @discussion.privateDefaultValue()

  computed:
    privacyTitle: ->
      if @discussion.private
        'common.privacy.private'
      else
        'common.privacy.public'

    privacyDescription: ->

      path = if @discussion.private == false
               'discussion_form.privacy_public'
             else if @discussion.group().parentMembersCanSeeDiscussions
               'discussion_form.privacy_organisation'
             else
               'discussion_form.privacy_private'
      @$t(path, {group:  @discussion.group().name, parent: @discussion.group().parentName()})

    groupSelectOptions: ->
      sortBy map(@availableGroups, (group) -> {
         text: group.fullName,
         value: group.id
      }), 'fullName'

    maxThreads: ->
      return null unless @discussion.group()
      @discussion.group().parentOrSelf().subscription.max_threads

    threadCount: ->
      return unless @discussion.group()
      @discussion.group().parentOrSelf().orgDiscussionsCount

    maxThreadsReached: ->
      @maxThreads && @threadCount >= @maxThreads

    subscriptionActive: ->
      return true unless @discussion.group()
      @discussion.group().parentOrSelf().subscription.active

    canStartThread: ->
      @subscriptionActive && !@maxThreadsReached

    showUpgradeMessage: ->
      @discussion.isNew() && !@canStartThread

    isMovingItems: ->
      @discussion.isForking

</script>

<template lang="pug">
.discussion-form(@keyup.ctrl.enter="submit()" @keydown.meta.enter.stop.capture="submit()")
  submit-overlay(:value='discussion.processing')
  v-card-title
    h1.headline
      span(v-if="isMovingItems" v-t="'discussion_form.moving_items_title'")
      template(v-else)
        span(v-if="discussion.isNew()" v-t="'discussion_form.new_discussion_title'")
        span(v-if="!discussion.isNew()" v-t="'discussion_form.edit_discussion_title'")
    v-spacer
    dismiss-modal-button(v-if="!isPage" aria-hidden='true', :close='close')
  .pa-4
    //- .lmo-hint-text(v-t="'group_page.discussions_placeholder'" v-show='discussion.isNew() && !isMovingItems')
    .body-1(v-if="showUpgradeMessage")
      p(v-if="maxThreadsReached" v-html="$t('discussion.max_threads_reached', {upgradeUrl: upgradeUrl, maxThreads: maxThreads})")
      p(v-if="!subscriptionActive" v-html="$t('discussion.subscription_canceled', {upgradeUrl: upgradeUrl})")

    .discussion-form__group-selected(v-if='discussion.groupId && discussion.group() && !showUpgradeMessage')
      p {{discussion.group().fullName}}
      v-text-field#discussion-title.discussion-form__title-input.lmo-primary-form-input(:label="$t('discussion_form.title_label')" :placeholder="$t('discussion_form.title_placeholder')" v-model='discussion.title' maxlength='255')
      validation-errors(:subject='discussion', field='title')
      lmo-textarea(:model='discussion' field="description" :label="$t('discussion_form.context_label')" :placeholder="$t('discussion_form.context_placeholder')")
        template(v-slot:actions)
          v-btn.discussion-form__submit(color="primary" @click="submit()" :disabled="submitIsDisabled || !discussion.groupId" v-t="'discussion_form.start_thread'" v-if="discussion.isNew()")
          v-btn.discussion-form__submit(color="primary" @click="submit()" :disabled="submitIsDisabled" v-t="'common.action.save'" v-if="!discussion.isNew()")
      v-list-item.discussion-form__privacy-notice
        v-list-item-avatar
          v-icon(v-if='discussion.private') mdi-lock-outline
          v-icon(v-if='!discussion.private') mdi-earth
        v-list-item-content
          v-list-item-title.discussion-privacy-icon__title(v-t="privacyTitle")
          v-list-item-subtitle.discussion-privacy-icon__subtitle(v-html='privacyDescription')
</template>
