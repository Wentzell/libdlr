      program dlr_ha_test

      ! Test discrete Lehmann representation using Green's function
      ! generated from Lehmann representation with density which is a
      ! sum of two delta functions. Recover DLR coefficients from
      ! samples of Green's function at DLR grid points, and then measure
      ! the error of the resulting expansion on a test grid.
      
      implicit none
      integer ntst
      real *8 lambda,eps,beta

      ! --- Input parameters ---

      lambda = 1000 ! Frequency cutoff
      eps = 1.0d-14 ! Desired accuracy
      ntst = 10000 ! # test points to check representation of G
      beta = 1000 ! Inverse temp: controls support of rho


      ! --- Call main test subroutine ---

      call dlr_ha_test_main(lambda,eps,ntst,beta)


      end program dlr_ha_test


      subroutine dlr_ha_test_main(lambda,eps,ntst,beta)

      ! Main driver routine for test of DLR basis on Green's function
      ! with two delta function density

      implicit none
      integer ntst
      real *8 lambda,eps,beta

      integer npt,npo,p,nt,no,i,j,rank,info,pg,npg
      integer, allocatable :: ipiv(:),tidx(:),oidx(:)
      real *8 one,gtrue,gtest,errl2,errlinf,kerr(2),gmax,gl2
      real *8, allocatable :: kmat(:,:),t(:),om(:),ttst(:)
      real *8, allocatable :: it2cf(:,:),dlrit(:),dlrrf(:),g(:),gc(:)
      real *8, allocatable :: xgl(:),wgl(:),xgj(:),wgj(:),pbpg(:)

      one = 1.0d0

      write(6,*) ''
      write(6,*) '---------------- Input parameters ----------------'
      write(6,*) ''
      write(6,*) 'Cutoff lambda            = ',lambda
      write(6,*) 'Error tolerance eps      = ',eps
      write(6,*) 'Inverse temp beta        = ',beta
      write(6,*) '# test points            = ',ntst


      ! --- Build DLR basis, grid, transform matrix ---

      ! Set parameters for the fine grid based on lambda

      call gridparams(lambda,p,npt,npo,nt,no)

      ! Get fine composite Chebyshev discretization of K(tau,omega)

      allocate(kmat(nt,no),t(nt),om(no))

      call kfine_cc(lambda,p,npt,npo,t,om,kmat,kerr)

      write(6,*) ''
      write(6,*) '-------------- Fine K discretization --------------'
      write(6,*) ''
      write(6,*) '# fine grid pts in tau     = ',nt
      write(6,*) '# fine grid pts in omega   = ',no
      write(6,*) 'Max rel L^inf err in tau   = ',kerr(1)
      write(6,*) 'Max rel L^inf err in omega = ',kerr(2)


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



      ! --- Compute actual eps-rank of fine grid K matrix by SVD ---

      write(6,*) ''
      write(6,*) '-------------------- DLR basis --------------------'
      write(6,*) ''
      write(6,*) 'DLR rank                          = ',rank


      ! --- Sample Green's function and get DLR ---


      ! Sample G(tau) at DLR grid points

      allocate(g(rank),gc(rank))

      do i=1,rank

        call gfun(beta,dlrit(i),g(i))

      enddo


      ! Compute coefficients of DLR expansion from samples

      call dlr_expnd(rank,it2cf,ipiv,g,gc)


      ! --- Compare DLR with true Green's function ---

      allocate(ttst(ntst))

      ! Get test points at which to measure error of Green's function;
      ! test points given in relative format

      call eqpts_rel(ntst,ttst)

      errlinf = 0*one
      errl2 = 0*one
      gmax = 0*one
      gl2 = 0*one

      do i=1,ntst

        ! Evaluate Green's function

        call gfun(beta,ttst(i),gtrue)

        ! Evaluate DLR

        call dlr_eval(rank,dlrrf,gc,ttst(i),gtest)

        ! Update L^inf and L^2 errors, norms

        errlinf = max(errlinf,abs(gtrue-gtest))
        errl2 = errl2 + (gtrue-gtest)**2

        gmax = max(gmax,abs(gtrue))
        gl2 = gl2 + gtrue**2

      enddo

      errl2 = sqrt((ttst(2)-ttst(1))*errl2)
      gl2 = sqrt((ttst(2)-ttst(1))*gl2)

      write(6,*) ''
      write(6,*) '-------------------- DLR error --------------------'
      write(6,*) ''
      write(6,*) 'Abs L^inf err = ',errlinf
      write(6,*) 'Abs L^2 err   = ',errl2
      write(6,*) 'Rel L^inf err = ',errlinf/gmax
      write(6,*) 'Rel L^2 err   = ',errl2/gl2
      write(6,*) ''

      ! Return failed status if error is not sufficiently small

      if (errlinf.gt.1.0d-13) then
        call exit(1)
      endif

      end subroutine dlr_ha_test_main



      subroutine gfun(beta,t,g)

      ! Evaluate Green's function corresponding to
      ! sum-of-delta-functions spectral density 

      implicit none
      real *8 beta,t,g
      real *8, external :: kfunf_rel

      real *8 a1,a2,a3,a4,a5

      a1 = -0.804d0
      a2 = -0.443d0
      a3 =  0.093d0
      a4 =  0.915d0
      a5 =  0.929d0

      g = kfunf_rel(t,beta*a1) + kfunf_rel(t,beta*a2) &
        + kfunf_rel(t,beta*a3) + kfunf_rel(t,beta*a4) &
        + kfunf_rel(t,beta*a5)

      end subroutine gfun
