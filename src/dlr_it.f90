      ! -------------------------------------------------------------
      !
      ! This file contains subroutines to work with the DLR in imaginary
      ! time
      !
      ! -------------------------------------------------------------
      !
      ! Copyright (C) 2021 The Simons Foundation
      ! 
      ! Author: Jason Kaye
      ! 
      ! -------------------------------------------------------------
      ! 
      ! libdlr is licensed under the Apache License, Version 2.0 (the
      ! "License"); you may not use this file except in compliance with
      ! the License.  You may obtain a copy of the License at
      ! 
      !     http://www.apache.org/licenses/LICENSE-2.0
      ! 
      ! Unless required by applicable law or agreed to in writing,
      ! software distributed under the License is distributed on an "AS
      ! IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
      ! express or implied.  See the License for the specific language
      ! governing permissions and limitations under the License.
      ! 
      ! -------------------------------------------------------------



      !> Get DLR frequency nodes and DLR imaginary time nodes
      !!
      !! @param[in]     lambda  dimensionless cutoff parameter
      !! @param[in]     eps     DLR error tolerance
      !! @param[in,out] r       On input, maximum possible number of DLR
      !!                          basis functions, defining input size
      !!                          of various arrays; on output, number
      !!                          of DLR basis functions.
      !! @param[out]    dlrrf   DLR frequency nodes
      !! @param[out]    dlrit   DLR imaginary time nodes

      subroutine dlr_it_build(lambda,eps,r,dlrrf,dlrit)

      implicit none
      integer r
      real *8 lambda,eps,dlrrf(r),dlrit(r)

      integer p,npt,npo,nt,no
      integer, allocatable :: oidx(:)
      real *8 kerr(2)
      real *8, allocatable :: kmat(:,:),t(:),om(:)


      ! Set parameters for fine grid

      call ccfine_init(lambda,p,npt,npo,nt,no)


      ! Get composite Chebyshev fine discretization of Lehmann kernel

      allocate(kmat(nt,no),t(nt),om(no))

      call ccfine(lambda,p,npt,npo,t,om)

      call dlr_kfine(lambda,p,npt,npo,t,om,kmat,kerr)


      ! Select DLR frequency nodes

      r = 500 ! Upper bound on possible DLR rank

      allocate(oidx(r))

      call dlr_rf(lambda,eps,nt,no,om,kmat,r,dlrrf,oidx)


      ! Get DLR imaginary time nodes

      call dlr_it(lambda,nt,no,t,kmat,r,oidx,dlrit)

      end subroutine dlr_it_build





      !> Get DLR imaginary time nodes
      !!
      !! @param[in]  lambda  dimensionless cutoff parameter
      !! @param[in]  nt      number of imaginary time fine grid points
      !! @param[in]  no      number of Matsubara frequency fine grid
      !!                       points
      !! @param[in]  t       imaginary time fine grid points
      !! @param[in]  kmat    kernel K(tau,omega), sampled at fine grid
      !!                       points
      !! @param[in]  r       number of DLR basis functions
      !! @param[in]  oidx    column indices of kmat corresponding to
      !!                          DLR frequency nodes
      !! @param[out] dlrit   DLR imaginary time nodes

      subroutine dlr_it(lambda,nt,no,t,kmat,r,oidx,dlrit)

      implicit none
      integer nt,no,r,oidx(r)
      real *8 lambda,t(nt),kmat(nt,no),dlrit(r)

      integer j,k
      integer, allocatable :: list(:),tidx(:)
      real *8, allocatable :: tmp(:,:),work(:)


      ! Get matrix of selected columns of fine discretization of Lehmann
      ! kernel, transposed 

      allocate(tmp(r,nt),list(nt),work(nt),tidx(r))

      do j=1,nt
        do k=1,r
          tmp(k,j) = kmat(j,oidx(k))
        enddo
      enddo

      ! Pivoted QR to select imaginary time nodes

      call iddr_qrpiv(r,nt,tmp,r,list,work)


      ! Rearrange indices to get selected imaginary time node indices

      call ind_rearrange(nt,r,list)


      ! Extract selected imaginary time nodes

      tidx = list(1:r)

      do j=1,r
        dlrit(j) = t(tidx(j))
      enddo
      
      end subroutine dlr_it





      !> Build transform matrix from DLR coefficients to values of DLR
      !! expansion on imaginary time grid
      !!
      !! To obtain the values of a DLR expansion on the imaginary time
      !! grid, apply the matrix cf2it to the vector of DLR coefficients
      !!
      !! @param[in]  r      number of DLR basis functions
      !! @param[in]  dlrrf  DLR frequency nodes
      !! @param[in]  dlrit  DLR imaginary time nodes
      !! @param[out] cf2it  DLR coefficients -> imaginary time grid
      !!                      values transform matrix

      subroutine dlr_cf2it(r,dlrrf,dlrit,cf2it)

      implicit none
      integer r
      real *8 dlrrf(r),dlrit(r),cf2it(r,r)

      integer i,j
      real *8, external :: kfunf_rel

      ! Get the matrix of DLR basis functions evaluated at DLR imaginary
      ! time nodes

      do j=1,r
        do i=1,r
          cf2it(i,j) = kfunf_rel(dlrit(i),dlrrf(j))
        enddo
      enddo

      end subroutine dlr_cf2it





      !> Build transform matrix from values of a Green's function on
      !! imaginary time grid to its DLR coefficients; matrix is stored
      !! in LU factored form
      !!
      !! To obtain the DLR coefficients of a Green's function from its
      !! values on the imaginary time grid, use the dlr_expnd subroutine
      !! with arrays it2cf and it2cfp generated by this subroutine.
      !!
      !! @param[in]  r       number of DLR basis functions
      !! @param[in]  dlrrf   DLR frequency nodes
      !! @param[in]  dlrit   DLR imaginary time nodes
      !! @param[out] it2cf   imaginary time grid values ->
      !!                       DLR coefficients transform matrix,
      !!                       stored in LAPACK LU factored format; LU
      !!                       factors
      !! @param[out] it2cfp  imaginary time grid values ->
      !!                        DLR coefficients transform matrix,
      !!                        stored in LAPACK LU factored format; LU
      !!                        pivots

      subroutine dlr_it2cf(r,dlrrf,dlrit,it2cf,it2cfp)

      implicit none
      integer r,it2cfp(r)
      real *8 dlrrf(r),dlrit(r),it2cf(r,r)

      integer j,k,info
      real *8, external :: kfunf_rel

      ! Get the matrix of DLR basis functions evaluated at DLR imaginary
      ! time nodes

      call dlr_cf2it(r,dlrrf,dlrit,it2cf)


      ! LU factorize

      call dgetrf(r,r,it2cf,r,it2cfp,info)

      end subroutine dlr_it2cf





      !> Build transform matrix from values of a Green's function G on
      !! imaginary time grid to values of reflection G(1-tau) on
      !! imaginary time grid
      !!
      !! To obtain the values of a reflected Green's function on the
      !! imaginary time grid, apply the matrix it2itr to the vector of
      !! values of the Green's function on the imaginary time grid
      !!
      !! @param[in]  r        number of DLR basis functions
      !! @param[in]  dlrrf    DLR frequency nodes
      !! @param[in]  dlrit    DLR imaginary time nodes
      !! @param[in]  it2cf    imaginary time grid values ->
      !!                        DLR coefficients transform matrix, stored in
      !!                        LAPACK LU factored format; LU factors
      !! @param[in]  it2cfp   imaginary time grid values ->
      !!                        DLR coefficients transform matrix, stored in
      !!                        LAPACK LU factored format; LU pivots
      !! @param[out] it2itr   imaginary time grid values -> reflected
      !!                        imaginary time grid values transform
      !!                        matrix

      subroutine dlr_it2itr(r,dlrrf,dlrit,it2cf,it2cfp,it2itr)

      implicit none
      integer r,it2cfp(r)
      real *8 dlrrf(r),dlrit(r),it2cf(r,r),it2itr(r,r)

      integer i,j,info
      real *8, external :: kfunf_rel

      ! Get matrix taking DLR coefficients to values of DLR expansion at
      ! imaginary time nodes reflected about tau = 1/2.

      do j=1,r
        do i=1,r
          it2itr(i,j) = kfunf_rel(-dlrit(i),dlrrf(j))
        enddo
      enddo


      ! Precompose with matrix taking DLR imaginary time grid values ->
      ! DLR coefficients

      it2itr = transpose(it2itr)

      call dgetrs('T',r,r,it2cf,r,it2cfp,it2itr,r,info)

      it2itr = transpose(it2itr)

      end subroutine dlr_it2itr





      !> Get DLR coefficients of a Green's function from its values on the
      !! imaginary time grid
      !!
      !! @param[in]  r         number of DLR basis functions
      !! @param[in]  it2cf     imaginary time grid values ->
      !!                         DLR coefficients transform matrix, stored in
      !!                         LAPACK LU factored format; LU factors
      !! @param[in]  it2cfp  imaginary time grid values ->
      !!                         DLR coefficients transform matrix, stored in
      !!                         LAPACK LU factored format; LU pivots
      !! @param[in]  g         values of Green's function at imaginary
      !!                         time grid points
      !! @param[out] gc        DLR coefficients of Green's function

      subroutine dlr_it_expnd(r,it2cf,it2cfp,g,gc)
      
      implicit none
      integer r,it2cfp(r)
      real *8 it2cf(r,r),g(r),gc(r)

      integer info

      ! Solve interpolation problem using DLR coefficients -> imaginary
      ! time grid values matrix stored in LU form

      gc = g

      call dgetrs('N',r,1,it2cf,r,it2cfp,gc,r,info)

      end subroutine dlr_it_expnd





      !> Evaluate a DLR expansion at an imaginary time point
      !!
      !! @param[in]  r      number of DLR basis functions
      !! @param[in]  dlrrf  DLR frequency nodes
      !! @param[in]  gc     DLR coefficients of expansion
      !! @param[in]  t      imaginary time point in relative format
      !! @param[out] gt     value of DLR expansion at t

      subroutine dlr_it_eval(r,dlrrf,gc,t,gt)

      implicit none
      integer r
      real *8 dlrrf(r),gc(r),t,gt

      integer i
      real *8 kval
      real *8, external :: kfunf

      ! Evaluate DLR basis functions and sum against DLR coefficients,
      ! taking into account relative format of given imaginary time
      ! point

      gt = 0.0d0
      do i=1,r

        if (t.ge.0.0d0) then
          kval = kfunf(t,dlrrf(i))
        else
          kval = kfunf(-t,-dlrrf(i))
        endif

        gt = gt + gc(i)*kval

      enddo

      end subroutine dlr_it_eval





      !> Get DLR coefficients from scattered data by least squares
      !! fitting
      !!
      !! @param[in]  r        number of DLR basis functions
      !! @param[in]  dlrrf    DLR frequency nodes
      !! @param[in]  nsamp    number of imaginary time points at which
      !!                        Green's function G is sampled
      !! @param[in]  tsamp    imaginary time points at which G is
      !!                        sampled, given in relative format
      !! @param[in]  gsamp    values of G at sampling points
      !! @param[out] gc       DLR coefficients of Green's function

      subroutine dlr_it_fit(r,dlrrf,nsamp,tsamp,gsamp,gc)

      implicit none
      integer r,nsamp
      real *8 dlrrf(r),tsamp(nsamp),gsamp(nsamp),gc(r)

      integer i,j,rank,lwork,info
      real *8 rcond
      integer, allocatable :: jpvt(:)
      real *8, allocatable :: kls(:,:),work(:),tmp(:)
      real *8, external :: kfunf_rel
      
      ! Get system matrix for least squares fitting; columns are DLR
      ! basis functions evaluated at imaginary time sampling points

      allocate(kls(nsamp,r))

      do j=1,r
        do i=1,nsamp
          kls(i,j) = kfunf_rel(tsamp(i),dlrrf(j))
        enddo
      enddo


      ! Get size of work array for least squares fitting

      allocate(work(1),jpvt(r),tmp(nsamp))

      call dgelsy(nsamp,r,1,kls,nsamp,tmp,nsamp,jpvt,rcond,rank,&
        work,-1,info)

      lwork = work(1)

      deallocate(work)


      ! Least squares fitting of data to determine DLR coefficients

      allocate(work(lwork))

      tmp = gsamp

      call dgelsy(nsamp,r,1,kls,nsamp,tmp,nsamp,jpvt,rcond,rank,&
        work,lwork,info)

      gc = tmp(1:r)

      end subroutine dlr_it_fit
