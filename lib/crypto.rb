module Crypto
  
  # RSA modular exponentiation
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