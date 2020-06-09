function err_on_n (n)
    if n==0 then error(); exit(1);
    else err_on_n (n-1); exit(1);
    end
  end

  assert(not pcall(err_on_n, 0))