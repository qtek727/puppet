require 'spec_helper'

describe "Puppet::Util::Windows::User", :if => Puppet::Util::Platform.windows? do
  describe "2003 without UAC" do
    before :each do
      allow(Puppet::Util::Windows::Process).to receive(:windows_major_version).and_return(5)
      allow(Puppet::Util::Windows::Process).to receive(:supports_elevated_security?).and_return(false)
    end

    it "should be an admin if user's token contains the Administrators SID" do
      expect(Puppet::Util::Windows::User).to receive(:check_token_membership).and_return(true)

      expect(Puppet::Util::Windows::User).to be_admin
    end

    it "should not be an admin if user's token doesn't contain the Administrators SID" do
      expect(Puppet::Util::Windows::User).to receive(:check_token_membership).and_return(false)

      expect(Puppet::Util::Windows::User).not_to be_admin
    end

    it "should raise an exception if we can't check token membership" do
      expect(Puppet::Util::Windows::User).to receive(:check_token_membership).and_raise(Puppet::Util::Windows::Error, "Access denied.")

      expect { Puppet::Util::Windows::User.admin? }.to raise_error(Puppet::Util::Windows::Error, /Access denied./)
    end
  end

  context "2008 with UAC" do
    before :each do
      allow(Puppet::Util::Windows::Process).to receive(:windows_major_version).and_return(6)
      allow(Puppet::Util::Windows::Process).to receive(:supports_elevated_security?).and_return(true)
    end

    describe "in local administrators group" do
      before :each do
        allow(Puppet::Util::Windows::User).to receive(:check_token_membership).and_return(true)
      end

      it "should be an admin if user is running with elevated privileges" do
        allow(Puppet::Util::Windows::Process).to receive(:elevated_security?).and_return(true)

        expect(Puppet::Util::Windows::User).to be_admin
      end

      it "should not be an admin if user is not running with elevated privileges" do
        allow(Puppet::Util::Windows::Process).to receive(:elevated_security?).and_return(false)

        expect(Puppet::Util::Windows::User).not_to be_admin
      end

      it "should raise an exception if the process fails to open the process token" do
        allow(Puppet::Util::Windows::Process).to receive(:elevated_security?).and_raise(Puppet::Util::Windows::Error, "Access denied.")

        expect { Puppet::Util::Windows::User.admin? }.to raise_error(Puppet::Util::Windows::Error, /Access denied./)
      end
    end

    describe "not in local administrators group" do
      before :each do
        allow(Puppet::Util::Windows::User).to receive(:check_token_membership).and_return(false)
      end

      it "should not be an admin if user is running with elevated privileges" do
        allow(Puppet::Util::Windows::Process).to receive(:elevated_security?).and_return(true)

        expect(Puppet::Util::Windows::User).not_to be_admin
      end

      it "should not be an admin if user is not running with elevated privileges" do
        allow(Puppet::Util::Windows::Process).to receive(:elevated_security?).and_return(false)

        expect(Puppet::Util::Windows::User).not_to be_admin
      end
    end
  end

  describe "module function" do
    let(:username) { 'fabio' }
    let(:bad_password) { 'goldilocks' }
    let(:logon_fail_msg) { /Failed to logon user "fabio":  Logon failure: unknown user name or bad password./ }

    def expect_logon_failure_error(&block)
      expect {
        yield
      }.to raise_error { |error|
        expect(error).to be_a(Puppet::Util::Windows::Error)
        # https://msdn.microsoft.com/en-us/library/windows/desktop/ms681385(v=vs.85).aspx
        # ERROR_LOGON_FAILURE 1326
        expect(error.code).to eq(1326)
      }
    end

    describe "load_profile" do
      it "should raise an error when provided with an incorrect username and password" do
        expect_logon_failure_error {
          Puppet::Util::Windows::User.load_profile(username, bad_password)
        }
      end

      it "should raise an error when provided with an incorrect username and nil password" do
        expect_logon_failure_error {
          Puppet::Util::Windows::User.load_profile(username, nil)
        }
      end
    end

    describe "logon_user" do
      it "should raise an error when provided with an incorrect username and password" do
        expect_logon_failure_error {
          Puppet::Util::Windows::User.logon_user(username, bad_password)
        }
      end

      it "should raise an error when provided with an incorrect username and nil password" do
        expect_logon_failure_error {
          Puppet::Util::Windows::User.logon_user(username, nil)
        }
      end
    end

    describe "password_is?" do
      it "should return false given an incorrect username and password" do
        expect(Puppet::Util::Windows::User.password_is?(username, bad_password)).to be_falsey
      end

      it "should return false given a nil username and an incorrect password" do
        expect(Puppet::Util::Windows::User.password_is?(nil, bad_password)).to be_falsey
      end

      context "with a correct password" do
        it "should return true even if account restrictions are in place " do
          error = Puppet::Util::Windows::Error.new('', Puppet::Util::Windows::User::ERROR_ACCOUNT_RESTRICTION)
          allow(Puppet::Util::Windows::User).to receive(:logon_user).and_raise(error)
          expect(Puppet::Util::Windows::User.password_is?(username, 'p@ssword')).to be(true)
        end

        it "should return true even for an account outside of logon hours" do
          error = Puppet::Util::Windows::Error.new('', Puppet::Util::Windows::User::ERROR_INVALID_LOGON_HOURS)
          allow(Puppet::Util::Windows::User).to receive(:logon_user).and_raise(error)
          expect(Puppet::Util::Windows::User.password_is?(username, 'p@ssword')).to be(true)
        end

        it "should return true even for an account not allowed to log into this workstation" do
          error = Puppet::Util::Windows::Error.new('', Puppet::Util::Windows::User::ERROR_INVALID_WORKSTATION)
          allow(Puppet::Util::Windows::User).to receive(:logon_user).and_raise(error)
          expect(Puppet::Util::Windows::User.password_is?(username, 'p@ssword')).to be(true)
        end

        it "should return true even for a disabled account" do
          error = Puppet::Util::Windows::Error.new('', Puppet::Util::Windows::User::ERROR_ACCOUNT_DISABLED)
          allow(Puppet::Util::Windows::User).to receive(:logon_user).and_raise(error)
          expect(Puppet::Util::Windows::User.password_is?(username, 'p@ssword')).to be(true)
        end
      end
    end

    describe "check_token_membership" do
      it "should not raise an error" do
        # added just to call an FFI code path on all platforms
        expect { Puppet::Util::Windows::User.check_token_membership }.not_to raise_error
      end
    end
  end
end
