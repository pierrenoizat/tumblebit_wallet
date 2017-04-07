FactoryGirl.define do
  factory :payment_request do
    title "MyString"
    tumbler_public_key "MyString"
    bob_public_key "MyString"
    expiry_date "2017-04-02"
    r "MyString"
    real_indices "MyText"
    beta_values "MyText"
    c_values "MyText"
    epsilon_values "MyText"
  end
end
