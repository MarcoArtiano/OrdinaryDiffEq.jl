function ode_solve{uType<:Number,tType,ksEltype,TabType,SolType,rateType,F,ECType,O}(integrator::ODEIntegrator{Euler,uType,tType,ksEltype,TabType,SolType,rateType,F,ECType,O})
  @ode_preamble
  k = f(t,u) # For the interpolation, needs k at the updated point
  @inbounds for T in Ts
    while t < T
      @ode_loopheader
      u = muladd(dt,k,u)
      k = f(t,u) # For the interpolation, needs k at the updated point
      @ode_loopfooter
    end
  end
  ode_postamble!(integrator)
  nothing
end

function ode_solve{uType<:AbstractArray,tType,ksEltype,TabType,SolType,rateType,F,ECType,O}(integrator::ODEIntegrator{Euler,uType,tType,ksEltype,TabType,SolType,rateType,F,ECType,O})
  @ode_preamble
  uidx = eachindex(u)
  if !integrator.opts.dense
    k = similar(rate_prototype) # Not initialized if not dense
  end
  if !(typeof(integrator.opts.callback)<:Void)
    cache = (u,integrator.uprev,k)
  end
  f(t,u,k) # For the interpolation, needs k at the updated point
  @inbounds for T in Ts
      while t < T
      @ode_loopheader
      for i in uidx
        u[i] = muladd(dt,k[i],u[i])
      end
      f(t,u,k) # For the interpolation, needs k at the updated point
      @ode_loopfooter
    end
  end
  ode_postamble!(integrator)
  nothing
end

function ode_solve{uType<:Number,tType,ksEltype,TabType,SolType,rateType,F,ECType,O}(integrator::ODEIntegrator{Midpoint,uType,tType,ksEltype,TabType,SolType,rateType,F,ECType,O})
  @ode_preamble
  halfdt::tType = dt/2
  local du::rateType
  @inbounds for T in Ts
    while t < T
      @ode_loopheader
      k = f(t+halfdt,u+halfdt*f(t,u))
      u = u + dt*k
      @ode_loopfooter
    end
  end
  ode_postamble!(integrator)
  nothing
end

function ode_solve{uType<:AbstractArray,tType,ksEltype,TabType,SolType,rateType,F,ECType,O}(integrator::ODEIntegrator{Midpoint,uType,tType,ksEltype,TabType,SolType,rateType,F,ECType,O})
  @ode_preamble
  halfdt::tType = dt/2
  utilde::uType = similar(u)
  uidx = eachindex(u)
  if integrator.opts.calck # Not initialized if not dense
    if integrator.calcprevs
      integrator.kprev = similar(rate_prototype)
    end
  end
  k = similar(rate_prototype)
  du = similar(rate_prototype)
  if !(typeof(integrator.opts.callback)<:Void)
    if integrator.opts.calck
      cache = (u,k,du,utilde,integrator.kprev,integrator.uprev)
    else
      cache = (u,k,du,utilde,integrator.uprev)
    end
  end
  @inbounds for T in Ts
      while t < T
      @ode_loopheader
      f(t,u,du)
      for i in uidx
        utilde[i] = muladd(halfdt,du[i],u[i])
      end
      f(t+halfdt,utilde,k)
      for i in uidx
        u[i] = muladd(dt,k[i],u[i])
      end
      @ode_loopfooter
    end
  end
  ode_postamble!(integrator)
  nothing
end

function ode_solve{uType<:Number,tType,ksEltype,TabType,SolType,rateType,F,ECType,O}(integrator::ODEIntegrator{RK4,uType,tType,ksEltype,TabType,SolType,rateType,F,ECType,O})
  @ode_preamble
  halfdt::tType = dt/2
  local k₁::rateType
  local k₂::rateType
  local k₃::rateType
  local k₄::rateType
  local ttmp::tType
  @inbounds for T in Ts
      while t < T
      @ode_loopheader
      k₁ = f(t,u)
      ttmp = t+halfdt
      k₂ = f(ttmp,muladd(halfdt,k₁,u))
      k₃ = f(ttmp,muladd(halfdt,k₂,u))
      k₄ = f(t+dt,muladd(dt,k₃,u))
      u = muladd(dt/6,muladd(2,(k₂ + k₃),k₁+k₄),u)
      if integrator.opts.calck
        k=k₁
      end
      @ode_loopfooter
    end
  end
  ode_postamble!(integrator)
  nothing
end

function ode_solve{uType<:AbstractArray,tType,ksEltype,TabType,SolType,rateType,F,ECType,O}(integrator::ODEIntegrator{RK4,uType,tType,ksEltype,TabType,SolType,rateType,F,ECType,O})
  @ode_preamble
  halfdt::tType = dt/2
  k₁ = similar(rate_prototype)
  k₂ = similar(rate_prototype)
  k₃ = similar(rate_prototype)
  k₄ = similar(rate_prototype)
  if integrator.calcprevs
    integrator.kprev = similar(rate_prototype)
  end
  tmp = similar(u)
  uidx = eachindex(u)
  if !(typeof(integrator.opts.callback)<:Void)
    cache = (u,tmp,k₁,k₂,k₃,k₄,integrator.kprev,integrator.uprev)
  end
  if integrator.opts.calck
    k=k₁
  end
  @inbounds for T in Ts
    while t < T
      @ode_loopheader
      f(t,u,k₁)
      ttmp = t+halfdt
      for i in uidx
        tmp[i] = muladd(halfdt,k₁[i],u[i])
      end
      f(ttmp,tmp,k₂)
      for i in uidx
        tmp[i] = muladd(halfdt,k₂[i],u[i])
      end
      f(ttmp,tmp,k₃)
      for i in uidx
        tmp[i] = muladd(dt,k₃[i],u[i])
      end
      f(t+dt,tmp,k₄)
      for i in uidx
        u[i] = muladd(dt/6,muladd(2,(k₂[i] + k₃[i]),k₁[i] + k₄[i]),u[i])
      end
      @ode_loopfooter
    end
  end
  ode_postamble!(integrator)
  nothing
end
