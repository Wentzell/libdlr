      program dlr_sc_it_test

      ! DLR for imaginary time Green's function corresponding to
      ! semi-circular density of states, rho(omega) = sqrt(1-omega^2),
      ! using imaginary time sampling.
      !
      ! DLR expansion is formed from samples at imaginary time sampling
      ! nodes, and then evaluated both in imaginary time and Matsubara
      ! frequency domains, where its accuracy is measured.
      !
      ! The Green's function is evaluated from the Lehmann
      ! representation using a high-order accurate composite Gauss
      ! quadrature rule, with Gauss-Jacobi nodes corresponding to square
      ! root weighting at the end panels. Subroutines to evaluate the
      ! Green's function in imaginary time and Matsubara frequency are
      ! defined at the bottom of this file.
      
      implicit none
      integer ntst_it,ntst_mf
      real *8 lambda,eps,beta
      character :: fb

      ! --- Input parameters ---

      lambda = 1000 ! Frequency cutoff
      eps = 1.0d-14 ! Desired accuracy
      beta = 1000 ! Inverse temperature

      ntst_it = 1000 ! # test points to check representation of G(tau)
      ntst_mf = 1000 ! Max |n| at which to test G(i omega_n)

      fb = 'f' ! Fermion or Boson? (this switch isn't working yet)


      ! --- Call main test subroutine ---

      call dlr_sc_it_test_main(lambda,eps,ntst_it,ntst_mf,beta,fb)


      end program dlr_sc_it_test


      subroutine dlr_sc_it_test_main(lambda,eps,ntst_it,ntst_mf,beta,fb)

      ! Main driver routine for test of DLR basis on Green's function
      ! with semi-circular density

      implicit none
      integer ntst_it,ntst_mf
      real *8 lambda,eps,beta
      character :: fb

      integer npt,npo,p,nt,no,i,j,rank,info,pg,npg
      integer, allocatable :: ipiv(:),tidx(:),oidx(:),mf_tst(:)
      real *8 one,kerr(2)
      real *8, allocatable :: kmat(:,:),t(:),om(:),it_tst(:)
      real *8, allocatable :: it2cf(:,:),dlrit(:),dlrrf(:),g(:),gc(:)
      real *8, allocatable :: xgl(:),wgl(:),xgj(:),wgj(:),pbpg(:)
      real *8, allocatable :: gtst_it(:),gtrue_it(:)
      complex *16, allocatable :: gtst_mf(:),gtrue_mf(:)

      one = 1.0d0

      ! --- Build DLR basis, imaginary time grid, transform matrix ---

      ! Set parameters for the fine grid based on lambda

      call gridparams(lambda,p,npt,npo,nt,no)


      ! Get fine composite Chebyshev discretization of K(tau,omega)

      allocate(kmat(nt,no),t(nt),om(no))

      call kfine_cc(fb,lambda,p,npt,npo,t,om,kmat,kerr)


      ! Select real frequency points for DLR basis

      rank = 500 ! Upper bound on possible rank

      allocate(dlrrf(rank),oidx(rank))

      call dlr_rf(lambda,eps,nt,no,om,kmat,rank,dlrrf,oidx)


      ! Get DLR imaginary time grid

      allocate(dlrit(rank),tidx(rank))

      call dlr_it(lambda,nt,no,t,kmat,rank,oidx,dlrit,tidx)


      ! Get imaginary time values -> DLR coefficients transform matrix in LU form

      allocate(it2cf(rank,rank),ipiv(rank))

      call dlr_it2cf(nt,no,kmat,rank,oidx,tidx,it2cf,ipiv)



      ! --- Sample Green's function and obtain DLR coefficients ---

      ! Initialize Green's function evaluator

      pg = 24
      npg = npo
      
      allocate(xgl(pg),wgl(pg),xgj(pg),wgj(pg),pbpg(2*no+1))

      call gfun_init(pg,npg,pbpg,xgl,wgl,xgj,wgj)


      ! Sample G(tau) at DLR imaginary time grid points

      allocate(g(rank),gc(rank))

      do i=1,rank

        call gfun_it(pg,npg,pbpg,xgl,wgl,xgj,wgj,fb,beta,dlrit(i),&
          g(i))

      enddo


      ! Compute coefficients of DLR expansion from samples

      call dlr_expnd(rank,it2cf,ipiv,g,gc)


      ! --- Evaluate DLR in imaginary time and Matsubara frequency
      ! domains ---

      ! Get imaginary time evaluation points in relative format

      allocate(it_tst(ntst_it))

      call eqpts_rel(ntst_it,it_tst)


      ! Evaluate DLR in imaginary time

      allocate(gtst_it(ntst_it))

      do i=1,ntst_it

        call dlr_eval(fb,rank,dlrrf,gc,it_tst(i),gtst_it(i))

      enddo


      ! Get Matsubara frequency evaluation points

      allocate(mf_tst(2*ntst_mf+1))

      do i=1,2*ntst_mf+1
        mf_tst(i) = -ntst_mf+i-1
      enddo


      ! Evaluate DLR in Matsubara frequency

      allocate(gtst_mf(2*ntst_mf+1))

      do i=1,2*ntst_mf+1

        call dlr_mf_eval(fb,rank,dlrrf,gc,mf_tst(i),gtst_mf(i))

      enddo



      ! --- Measure accuracy of DLR expansions in imaginary time and
      ! Matsubara frequency ---


      ! Evaluate Green's function at imaginary time test points

      allocate(gtrue_it(ntst_it))

      do i=1,ntst_it

        call gfun_it(pg,npg,pbpg,xgl,wgl,xgj,wgj,fb,beta,it_tst(i),&
          gtrue_it(i))

      enddo


      ! Evaluate Green's function at Matsubara frequency test points

      allocate(gtrue_mf(2*ntst_mf+1))

      do i=1,2*ntst_mf+1

        call gfun_mf(pg,npg,pbpg,xgl,wgl,xgj,wgj,fb,beta,mf_tst(i),&
          gtrue_mf(i))

      enddo


      ! Output error


      write(6,*) ''
      write(6,*) '-------------------- DLR error --------------------'
      write(6,*) ''
      write(6,*) 'Imag time max err = ',maxval(abs(gtst_it-gtrue_it))
      write(6,*) 'Mats freq max err = ',maxval(abs(gtst_mf-gtrue_mf))
      write(6,*) ''


      end subroutine dlr_sc_it_test_main



      subroutine gfun_init(n,np,pbp,xgl,wgl,xgj,wgj)

      ! --- Initialization routine for evaluation of Green's function
      ! with semi-circular density ---

      implicit none
      integer n,np
      real *8 pbp(2*np+1),xgl(n),wgl(n),xgj(n),wgj(n)

      integer i
      real *8 one

      one = 1.0d0

      ! --- Gauss-Legendre and Gauss-Jacobi quadrature ---

      call cdgqf(n,1,0.0d0,0.0d0,xgl,wgl)
      call cdgqf(n,4,0.5d0,0.0d0,xgj,wgj)

      ! --- Panels endpoints for composite quadrature rule ---

      pbp(np+1) = 0*one
      do i=1,np
        pbp(np+i+1) = one/2**(np-i)
      enddo
      pbp(1:np) = -pbp(2*np+1:np+2:-1)


      end subroutine gfun_init


      subroutine gfun_it(n,np,pbp,xgl,wgl,xgj,wgj,fb,beta,t,val)

      ! Evaluate Green's function with semi-circular density
      !
      ! This is a wrapper for the main subroutine, gfun_it1

      implicit none
      integer n,np
      real *8 pbp(2*np+1),xgl(n),wgl(n),xgj(n),wgj(n),beta,t,val
      real *8, external :: kfunf,kfunb
      character :: fb

      if (fb.eq.'f') then
        call gfun_it1(n,np,pbp,xgl,wgl,xgj,wgj,kfunf,beta,t,val)
      elseif (fb.eq.'b') then
        call gfun_it1(n,np,pbp,xgl,wgl,xgj,wgj,kfunb,beta,t,val)
      else
        stop 'choose fb = f or b'
      endif

      end subroutine gfun_it


      subroutine gfun_it1(n,np,pbp,xgl,wgl,xgj,wgj,kfun,beta,t,val)

      ! Evaluate Green's function with semi-circular density
      !
      ! Main subroutine

      implicit none
      integer n,np
      real *8 pbp(2*np+1),xgl(n),wgl(n),xgj(n),wgj(n),beta,t,val
      real *8, external :: kfun

      integer ii,jj
      real *8 one,a,b,x,tt

      one = 1.0d0

      ! Treat t near 1 by symmetry to maintain high relative precision
      ! in the value of t. Note t near 1 is store by the negative of
      ! its distance to 1.

      tt = abs(t)

      val = 0.0d0
      do ii=2,2*np-1
        a = pbp(ii)
        b = pbp(ii+1)
        do jj=1,n
          x = a+(b-a)*(xgl(jj)+one)/2
          val = val + (b-a)/2*wgl(jj)*kfun(tt,beta*x)*&
            sqrt(one-x**2)
        enddo
      enddo

      a = one/2
      b = one
      do jj=1,n
        x = a+(b-a)*(xgj(jj)+one)/2
        val = val + ((b-a)/2)**(1.5d0)*wgj(jj)*&
          kfun(tt,beta*x)*sqrt(one+x)
      enddo

      a = -one
      b = -one/2
      do jj=1,n
        x = a+(b-a)*(-xgj(n-jj+1)+one)/2
        val = val + ((b-a)/2)**(1.5d0)*wgj(n-jj+1)*&
          kfun(tt,beta*x)*sqrt(one-x)
      enddo
        

      end subroutine gfun_it1




      subroutine gfun_mf(n,np,pbp,xgl,wgl,xgj,wgj,fb,beta,m,val)

      ! Evaluate Green's function with semi-circular density in
      ! Matsubara frequency domain
      !
      ! This is a wrapper for the main subroutine, gfunsc1

      implicit none
      integer n,np,m
      real *8 pbp(2*np+1),xgl(n),wgl(n),xgj(n),wgj(n),beta
      complex *16 val
      complex *16, external :: kfunf_mf
      character :: fb

      if (fb.eq.'f') then
        call gfun_mf1(n,np,pbp,xgl,wgl,xgj,wgj,kfunf_mf,beta,m,val)
      !elseif (fb.eq.'b') then
      !  call gfun_mf1(n,np,pbp,xgl,wgl,xgj,wgj,kfunb,beta,t,val)
      else
        stop 'choose fb = f or b'
      endif

      end subroutine gfun_mf


      subroutine gfun_mf1(n,np,pbp,xgl,wgl,xgj,wgj,kfun,beta,m,val)

      ! Evaluate Green's function with semi-circular density in
      ! Matsubara frequency domain
      !
      ! Main subroutine

      implicit none
      integer n,np,m
      real *8 pbp(2*np+1),xgl(n),wgl(n),xgj(n),wgj(n),beta
      complex *16 val
      complex *16, external :: kfun

      integer ii,jj
      real *8 one,a,b,x

      one = 1.0d0

      val = 0.0d0
      do ii=2,2*np-1
        a = pbp(ii)
        b = pbp(ii+1)
        do jj=1,n
          x = a+(b-a)*(xgl(jj)+one)/2
          val = val + (b-a)/2*wgl(jj)*kfun(m,beta*x)*&
            sqrt(one-x**2)
        enddo
      enddo

      a = one/2
      b = one
      do jj=1,n
        x = a+(b-a)*(xgj(jj)+one)/2
        val = val + ((b-a)/2)**(1.5d0)*wgj(jj)*&
          kfun(m,beta*x)*sqrt(one+x)
      enddo

      a = -one
      b = -one/2
      do jj=1,n
        x = a+(b-a)*(-xgj(n-jj+1)+one)/2
        val = val + ((b-a)/2)**(1.5d0)*wgj(n-jj+1)*&
          kfun(m,beta*x)*sqrt(one-x)
      enddo
        

      end subroutine gfun_mf1
