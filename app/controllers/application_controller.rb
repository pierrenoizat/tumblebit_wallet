class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  helper_method :current_user
  helper_method :user_signed_in?
  helper_method :correct_user?
  helper_method :user_admin?
  helper_method :script_user?
  helper_method :valid_pubkey?
  helper_method :mod_pow, :create_random_bignum, :create_random_prime, 

  private
  
    def current_user
      begin
        @current_user ||= User.find(session[:user_id]) if session[:user_id]
      rescue Exception => e
        nil
      end
    end

    def user_signed_in?
      return true if current_user
    end
    
    def user_admin?
      if current_user
        current_user.uid == Figaro.env.btcscript_admin_uid.to_s
      end
    end

    def correct_user?
      @user = User.find_by_id(params[:id])
      unless (current_user and current_user == @user)
        redirect_to root_url, :alert => "Access denied."
      end
    end
    
    def correct_client?
      unless user_admin?
        @client = Client.find_by_id(params[:id])
        unless (current_client and current_client == @client)
          redirect_to root_url, :alert => "Access denied."
        end
      end
    end
    
    def script_user?
      @script = Script.find(params[:id])
      unless current_user
        if current_client and @script.client_id
          @client = Client.find(@script.client_id)
          unless current_client == @client
          redirect_to scripts_url, :alert => "Access denied: this contract belongs to another user."
          end
        else
          redirect_to scripts_url, :alert => "Access denied: this contract belongs to another user."
        end
      end
      
      if current_user and @script.user_id
        @user = User.find(@script.user_id)
        unless current_user == @user
        redirect_to scripts_url, :alert => "Access denied: this contract belongs to another user."
        end
      end
    end

    def authenticate_user!
      if !current_user
        if !current_client
          redirect_to root_url, :alert => 'You need to log in or sign up for access to this page.'
        end
      end
    end
    
    def bitcoin_elliptic_curve
          ::OpenSSL::PKey::EC.new("secp256k1")
        end
        
    def valid_pubkey?(pubkey)
      ::OpenSSL::PKey::EC::Point.from_hex(bitcoin_elliptic_curve.group, pubkey)
      true
      rescue OpenSSL::PKey::EC::Point::Error,OpenSSL::BNError
      false
    end

    def mod_pow(base, power, mod)
      result = 1
      while power > 0
        result = (result * base) % mod if power & 1 == 1
        base = (base * base) % mod
        power >>= 1;
      end
      result
    end
    
    # Make a random bignum of size bits, with the highest two and low bit set
    def create_random_bignum(bits)
      middle = (1..bits-3).map{rand()>0.5 ? '1':'0'}.join
      str = "11" + middle + "1"
      str.to_i(2)
    end
    
    # Create random numbers until it finds a prime
    def create_random_prime(bits)
      while true
      val = create_random_bignum(bits)
      return val if val.prime?
      end
    end
    
    
    def dump_to_csv(puzzle_id)
      require 'openssl'
      require 'csv'
      @puzzle = Puzzle.find(puzzle_id)
      string = OpenSSL::Digest::SHA256.new.digest(puzzle_id.to_s).unpack('H*').first
      string = string[0..5]
      
      if File.exists?("tmp/puzzle_" + "#{string}" + ".csv")
        File.delete("tmp/puzzle_#{string}.csv") # delete any previous version of puzzle.csv file
        end
      
      CSV.open("tmp/puzzle_#{string}.csv", "ab") do |csv|

        @puzzle.beta_values.each do |beta|
          csv << [beta]
          end
        end # of CSV.open (writing to puzzle_123456.csv)
        
      end # of method dump_to_csv(puzzle_id))
    
  # Perform a primality test
  class Integer
    # From http://snippets.dzone.com/posts/show/4636
    
    def prime?
      n = self.abs()
      return true if n == 2
      return false if n == 1 || n & 1 == 0
      # cf. http://betterexplained.com/articles/another-look-at-prime-numbers/ and
      # http://everything2.com/index.pl?node_id=1176369
      return false if n > 3 && n % 6 != 1 && n % 6 != 5 # added
      d = n-1
      d >>= 1 while d & 1 == 0
      20.times do # 20 = k from above
        a = rand(n-2) + 1
        t = d
        y = mod_pow(a,t,n)
        while t != n-1 && y != 1 && y != n-1
          y = (y * y) % n
          t <<= 1
        end
        return false if y != n-1 && t & 1 == 0
      end
      return true
    end
  end

end
