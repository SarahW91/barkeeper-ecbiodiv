# frozen_string_literal: true

require 'test_helper'

class FreezersControllerTest < ActionController::TestCase
  setup do
    @freezer = freezers(:freezer1)
    user_log_in
  end

  test 'should get index' do
    get :index
    assert_response :success
  end

  test 'should show freezer' do
    get :show, params: { id: @freezer }
    assert_response :success
  end

  test 'should get new' do
    get :new
    assert_response :success
  end

  test 'should get edit' do
    get :edit, params: { id: @freezer }
    assert_response :success
  end

  test 'should create freezer' do
    assert_difference('Freezer.count') do
      post :create, params: { freezer: { freezercode: 'test_2' } }
    end

    assert_redirected_to freezers_path
  end

  test 'should update freezer' do
    patch :update, params: { id: @freezer, freezer: { name: 'test_3' } }
    assert_redirected_to freezers_path
  end

  test 'should destroy freezer' do
    assert_difference('Freezer.count', -1) do
      delete :destroy, params: { id: @freezer }
    end

    assert_redirected_to freezers_path
  end
end
