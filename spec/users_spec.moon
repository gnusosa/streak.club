import
  load_test_server
  close_test_server
  from require "lapis.spec.server"

import truncate_tables from require "lapis.spec.db"

import request, request_as from require "spec.helpers"

factory = require "spec.factory"
import Users from require "models"

describe "users", ->
  setup ->
    load_test_server!

  teardown ->
    close_test_server!

  before_each ->
    truncate_tables Users

  it "should create a user", ->
    factory.Users!

  it "should load index logged in", ->
    current_user = factory.Users!
    request_as current_user, "/"

  it "should load login", ->
    status, res = request "/login"
    assert.same 200, status

  it "should view user profile", ->
    user = factory.Users!
    status, res = request "/u/#{user.slug}"
    assert.same 200, status

  it "should register user", ->
    status, res, headers = request_as nil, "/register", {
      post: {
        username: "leafo"
        password: "hello"
        password_repeat: "hello"
        email: "leafo@example.com"
        accept_terms: "yes"
      }
    }

    assert.same 1, #Users\select!
    assert.same 302, status
    assert.same "http://127.0.0.1/", headers.location

  it "should log in user", ->
    user = factory.Users password: "hello world"

    status, res, headers = request_as nil, "/login", {
      post: {
        username: user.username\upper!
        password: "hello world"
      }
    }

    assert.same 302, status
    assert.same "http://127.0.0.1/", headers.location

  describe "with streaks", ->
    import Streaks, StreakSubmissions, Submissions, StreakUsers from require "models"
    local current_user

    before_each ->
      truncate_tables Streaks, StreakSubmissions, Submissions, StreakUsers
      current_user = factory.Users!

    it "in no streak", ->
      factory.Streaks state: "during"

      assert.same 0, #current_user\get_active_streaks!
      assert.same 0, #current_user\get_all_streaks!

    describe "in streaks of all states", ->
      before_each ->
        factory.Streaks state: "during" -- not in this one
        for state in *{"during", "before_start", "after_end"}
          streak = factory.Streaks state: state
          factory.StreakUsers streak_id: streak.id, user_id: current_user.id

      it "get active streaks and all streaks", ->
        assert.same 1, #current_user\get_active_streaks!
        assert.same 3, #current_user\get_all_streaks!

      it "should get submittable streaks", ->
         assert.same 1, #current_user\get_submittable_streaks!

    it "should get submittable streaks with submission", ->
      streaks = for i=1,3
        streak = factory.Streaks state: "during"
        factory.StreakUsers streak_id: streak.id, user_id: current_user.id
        streak

      factory.StreakSubmissions {
        streak_id: streaks[1].id
        user_id: current_user.id
      }
      assert.same 2, #current_user\get_submittable_streaks!
