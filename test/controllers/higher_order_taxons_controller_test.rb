require 'test_helper'

class HigherOrderTaxonsControllerTest < ActionController::TestCase
  setup do
    @higher_order_taxon = higher_order_taxons(:magnoliopsida)
    user_log_in
  end

  test "should get index" do
    get :index
    assert_response :success
  end

  test "should show higher order taxon" do
    get :show, params: { id: @higher_order_taxon }
    assert_response :success
  end

  test "should get edit" do
    get :edit, params: { id: @higher_order_taxon }
    assert_response :success
  end

  test "should create higher order taxon" do
    assert_difference('HigherOrderTaxon.count') do
      post :create, params: { higher_order_taxon: { name: 'Coniferopsida' } }
    end

    assert_redirected_to higher_order_taxons_path
  end

  test "should update higher order taxon" do
    patch :update, params: { id: @higher_order_taxon, higher_order_taxon: { name: 'Equisetophytina' } }
    assert_redirected_to higher_order_taxons_path
  end

  test "should destroy higher order taxon" do
    assert_difference('HigherOrderTaxon.count', -1) do
      delete :destroy,  params: { id: @higher_order_taxon }
    end

    assert_redirected_to higher_order_taxons_path
  end
end