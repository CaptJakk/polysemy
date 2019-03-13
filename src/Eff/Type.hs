{-# LANGUAGE DataKinds          #-}
{-# LANGUAGE DeriveFunctor      #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DerivingVia        #-}
{-# LANGUAGE FlexibleContexts   #-}
{-# LANGUAGE GADTs              #-}
{-# LANGUAGE KindSignatures     #-}
{-# LANGUAGE MonoLocalBinds     #-}
{-# LANGUAGE RankNTypes         #-}
{-# LANGUAGE TupleSections      #-}
{-# LANGUAGE TypeOperators      #-}
{-# LANGUAGE ViewPatterns       #-}

{-# OPTIONS_GHC -Wall       #-}

module Eff.Type
  ( module Eff.Type
  , MonadTrans (..)
  , Identity ()
  , type (~>)
  ) where

import Control.Monad.Trans (MonadTrans (..))
import Data.Functor.Identity
import Data.OpenUnion.Internal


newtype Lift m (s :: * -> *) (n :: * -> *) a = Lift
  { unLift :: m a
  }
  deriving Functor
  deriving (Applicative, Monad) via m

newtype Eff r a = Eff
  { runEff
        :: forall f
         . Functor f
        => Freer (Union r f) (f (), a)
  }

newtype Freer f a = Freer
  { runFreer :: forall m. Monad m => (f (Freer f) ~> m) -> m a
  }

instance Functor (Freer f) where
  fmap f (Freer m) = Freer $ \k -> fmap f $ m k
  {-# INLINE fmap #-}


instance Applicative (Freer f) where
  pure a = Freer $ const $ pure a
  {-# INLINE pure #-}

  Freer f <*> Freer a = Freer $ \k -> f k <*> a k
  {-# INLINE (<*>) #-}


instance Monad (Freer f) where
  return = pure
  {-# INLINE return #-}

  Freer ma >>= f = Freer $ \k -> do
    z <- ma k
    runFreer (f z) k
  {-# INLINE (>>=) #-}


------------------------------------------------------------------------------
-- | Run a natural transformation over `Freer`.
hoistEff :: (f (Freer f) ~> g (Freer g)) -> Freer f ~> Freer g
hoistEff nat (Freer m) = Freer $ \k -> m $ \u -> k $ nat u
{-# INLINE hoistEff #-}


------------------------------------------------------------------------------
-- | Lift a value into 'Freer'. When 'f' is 'Union', this specializes as
-- @Union -- r x -> Eff r x@
liftEff :: f (Freer f) a -> Freer f a
liftEff u = Freer $ \k -> k u
{-# INLINE liftEff #-}


------------------------------------------------------------------------------
-- | Embed the action of an effect into 'Eff'.
send :: Member eff r => eff Identity (Eff r) a -> Eff r a
send e = Eff $ _ -- fmap _ . liftEff . inj
{-# INLINE[3] send #-}


--------------------------------------------------------------------------------
---- | Embed the action of an effect into 'Eff'.
--sendM :: Member (Lift m) r => m a -> Eff r a
--sendM = liftEff . inj . Lift
--{-# INLINE[3] sendM #-}


--------------------------------------------------------------------------------
---- | Drop out of an 'Eff' stack into the only remaining monadic effect inside
---- it.
--runM :: Monad m => Eff '[Lift m] a -> m a
--runM = usingFreer $ \(extract -> Lift m) -> m
--{-# INLINE runM #-}


--------------------------------------------------------------------------------
---- | Like 'runM' but for pure computations.
--run :: Eff '[Lift Identity] a -> a
--run = runIdentity . runM
--{-# INLINE run #-}


--------------------------------------------------------------------------------
---- | @'flip' 'runFreer'@
--usingFreer :: Monad m => (f (Freer f) ~> m) -> Freer f a -> m a
--usingFreer k m = runFreer m k
--{-# INLINE usingFreer #-}


------ | Inject whole @'Union' r@ into a weaker @'Union' (any ': r)@ that has one
------ more summand.
------
------ /O(1)/
----weaken :: Union r (Eff r) a -> Union (any ': r) (Eff (any ': r)) a
----weaken (Union n e) = Union (n + 1) $ hoist raise e
----{-# INLINE weaken #-}

----------------------------------------------------------------------------------
------ | Analogous to MTL's 'lift'.
----raise :: Eff r a -> Eff (u ': r) a
----raise = hoistEff weaken
----{-# INLINE raise #-}

