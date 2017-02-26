require_relative "../test_helper"
require "mixins/address"
require "zen_wallet/hd/account/registry"
require "zen_wallet/persistence/repositories/address_repo"
module ZenWallet
  module HD
    class Account
      class RegistryTest < HDTest
        include AddressMixin

        def setup
          super
          @repo = mock
          @repo.responds_like_instance_of(Persistence::AddressRepo)
          @account = @acc_balance_model
          @keychain = account_keychain(@acc_balance_model)
          @subject = Registry.new(@account, @repo, @network, @keychain)
          @wid = @account.wallet_id
          @idx = @account.index
        end

        def test_create_address
          # Dissalow invalid keychain
          assert_raises(Registry::InvalidChainError) do
            @subject.send(:create_address, 11, 0)
          end
          # External keychain
          model = address_model(@account, 0, 0)
          @repo.expects(:create).with(equals(model))
          assert @subject.send(:create_address, 0, 0)
          # Internal keychain
          model = address_model(@account, 1, 0)
          @repo.expects(:create).with(equals(model))
          assert @subject.send(:create_address, 1, 0)
        end

        def test_fill_gap_limit
          chain = 0
          mock_loop = lambda do |i|
            lst = i.positive? ? i - 1 : nil
            @repo.expects(:last_idx).with(@wid, @idx, chain)
                 .returns(lst)
            model = address_model(@account, chain, i)
            @repo.expects(:create).with(equals(model))
          end
          20.times(&mock_loop)
          chain = 1
          5.times(&mock_loop)
          @repo.expects(:count).with(@wid, @idx, 0, has_txs: false).returns(0)
          @repo.expects(:count).with(@wid, @idx, 1, has_txs: false).returns(15)
          @subject.fill_gap_limit
          # @repo.expects(:count).with(@wid, @idx, 1, has_txs: false).returns(15)
        end

        def test_free_address
          # If has not requested
          expected = address_model(@account, 0, 10)
          @repo.expects(:free_address)
               .with(@wid, @idx, 0)
               .returns(expected)
          assert_equal expected, @subject.free_address(0)
        end

        def test_ensure_requested_mark
          models = (0..10).map { |i| address_model(@account, 0, i) }
          addrs = models.map(&:address)
          @repo.expects(:update_addresses).with(addrs, requested: true)
          @subject.ensure_requested_mark(addrs)
          # assert_equal models, (0..10).map do |i|
          #   address_model(@account, 0, i, requested: true)
          # end
        end

        def test_ensure_has_txs_mark
          models = (0..10).map { |i| address_model(@account, 0, i) }
          addrs = models.map(&:address)
          # @repo.expects(:find).with(addrs).returns(models)
          @repo.expects(:update_addresses).with(addrs, has_txs: true)
          @subject.ensure_has_txs_mark(addrs)
          # assert_equal models, ((0..10).map do |i|
          #   address_model(@account, 0, i, has_txs: true)
          # end)
        end

        def test_pluck_addresses
          addrs = (0..4).map { |i| address_model(@acc_balance_model, 0, i) }
          @repo.expects(:pluck_address)
               .with(@wid, @idx, 0, chain: 0).returns(addrs)
          assert_equal addrs, @subject.pluck_addresses(chain: 0)
          @repo.expects(:pluck_address)
               .with(@wid, @idx, 20, {}).returns(addrs)
          assert_equal addrs, @subject.pluck_addresses(offset: 20)
        end

      end
    end
  end
end
