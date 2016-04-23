#include "burstygap.hh"

BurstyGAP::BurstyGAP(Env &env, Ratings &ratings)
  : _env(env), _ratings(ratings),
    _n(env.n), _m(env.m), _k(env.k),
    _iter(0),
    _start_time(time(0)),
    _theta("theta", 0.3, 0.3, _n,_k,&_r),
    _beta(n),
    _prev_h(.0), _nh(.0),
    _save_ranking_file(false),
    _use_rate_as_score(true)
{
  gsl_rng_env_setup();
  const gsl_rng_type *T = gsl_rng_default;
  _r = gsl_rng_alloc(T);
  if (_env.seed)
    gsl_rng_set(_r, _env.seed);
  Env::plog("infer n:", _n);

  for (uint32_t n = 0; n < _n; ++n)
    _beta[n]  = new GPMatrix("beta", 0.3, 0.3, _m, _k, &_r);

  _hf = fopen(Env::file_str("/heldout.txt").c_str(), "w");
  if (!_hf)  {
    printf("cannot open heldout file:%s\n",  strerror(errno));
    exit(-1);
  }
  _vf = fopen(Env::file_str("/validation.txt").c_str(), "w");
  if (!_vf)  {
    printf("cannot open heldout file:%s\n",  strerror(errno));
    exit(-1);
  }
  _tf = fopen(Env::file_str("/test.txt").c_str(), "w");
  if (!_tf)  {
    printf("cannot open heldout file:%s\n",  strerror(errno));
    exit(-1);
  }
  _af = fopen(Env::file_str("/logl.txt").c_str(), "w");
  if (!_af)  {
    printf("cannot open logl file:%s\n",  strerror(errno));
    exit(-1);
  }
  _pf = fopen(Env::file_str("/precision.txt").c_str(), "w");
  if (!_pf)  {
    printf("cannot open logl file:%s\n",  strerror(errno));
    exit(-1);
  }  
  load_validation_and_test_sets();
}

BurstyGAP::~BurstyGAP()
{
  fclose(_hf);
  fclose(_vf);
  fclose(_af);
  fclose(_pf);
  fclose(_tf);
}

void
BurstyGAP::load_validation_and_test_sets()
{
  char buf[4096];
  sprintf(buf, "%s/validation.tsv", _env.datfname.c_str());
  FILE *validf = fopen(buf, "r");
  assert(validf);
  _ratings.read_generic(validf, &_validation_map);
  fclose(validf);

  sprintf(buf, "%s/test.tsv", _env.datfname.c_str());
  FILE *testf = fopen(buf, "r");
  assert(testf);
  _ratings.read_generic(testf, &_test_map);
  fclose(testf);
  printf("+ loaded validation and test sets from %s\n", _env.datfname.c_str());
  fflush(stdout);
  Env::plog("test ratings", _test_map.size());
  Env::plog("validation ratings", _validation_map.size());
}

void
BurstyGAP::initialize()
{
  _beta.initialize();
  _theta.initialize();

  _beta.initialize_exp();
  _theta.initialize_exp();

  if (_env.bias) {
    _thetabias.initialize();
    _thetabias.initialize_exp();
    
    _betabias.initialize();
    _betabias.initialize_exp();
  }

  if (_env.hier) {
    _thetarate.set_to_prior_curr();
    _thetarate.set_to_prior();
    
    _betarate.set_to_prior_curr();
    _betarate.set_to_prior();
    
    _hbeta.initialize();
    _hbeta.initialize_exp();
    //_hbeta.initialize_exp(_betarate.expected_v()[0]);
    
    _htheta.initialize();
    _htheta.initialize_exp();
    //_htheta.initialize_exp(_thetarate.expected_v()[0]);
  }
}


void
BurstyGAP::get_phi(GPBase<Matrix> &a, uint32_t ai, 
		 GPBase<Matrix> &b, uint32_t bi, 
		 Array &phi)
{
  assert (phi.size() == a.k() &&
	  phi.size() == b.k());
  assert (ai < a.n() && bi < b.n());
  const double  **eloga = a.expected_logv().const_data();
  const double  **elogb = b.expected_logv().const_data();
  phi.zero();
  for (uint32_t k = 0; k < _k; ++k)
    phi[k] = eloga[ai][k] + elogb[bi][k];
  phi.lognormalize();
}

void
BurstyGAP::vb()
{
  lerr("running vb()");
  initialize();
  // approx_log_likelihood();

  Array phi(_k);
  while (1) {
    for (uint32_t n = 0; n < _n; ++n) {
      const vector<uint32_t> *movies = _ratings.get_movies(n);
      for (uint32_t j = 0; j < movies->size(); ++j) {
	uint32_t m = (*movies)[j];
	yval_t y = _ratings.r(n,m);
	GPMatrix &beta = *_beta[m];
	
	get_phi(_theta, n, beta, m, phi);
	if (y > 1)
	  phi.scale(y);
	
	_theta.update_shape_next(n, phi);
	beta.update_shape_next(m, phi);
      }
    }
    
    for (uint32_t n = 0; n < _n; ++n) {
      for (uint32_t m = 0; m < _m; ++m) {
	GPMatrix &beta = *_beta[m];
	Array betasum(_k);
	beta.sum_rows(betasum);
	_theta.update_rate_next(n, betasum);
      }
    }
    _theta.swap();
    _theta.compute_expectations();

    for (uint32_t n = 0; n < _n; ++n) {
      for (uint32_t m = 0; m < _m; ++m) {
	GPMatrix &beta = *_beta[m];
	beta.set_prior_rate(_eta.expected_v(), _eta.expected_logv());
	for (uint32_t k = 0; k < _k; ++k)
	  beta.update_rate_next(k, thetad[n][k]);
      }
    }
    
    for (uint32_t n = 0; n < _n; ++n) {
      GPMatrix &beta = *_beta[n];
      beta.swap();
      beta.compute_expectations();
      for (uint32_t m = 0; m < _m; ++m) {
	etarate[m] += 
    }

    printf("\r iteration %d", _iter);
    fflush(stdout);
    if (_iter % _env.reportfreq == 0) {
      // approx_log_likelihood();
      compute_likelihood(true);
      compute_likelihood(false);
      compute_precision(false);
    }

    if (_env.save_state_now) {
      lerr("Saving state at iteration %d duration %d secs", _iter, duration());
      do_on_stop();
      exit(0);
    }

    _iter++;
  }
}

void
BurstyGAP::compute_likelihood(bool validation)
{
  uint32_t k = 0, kzeros = 0, kones = 0;
  double s = .0, szeros = 0, sones = 0;
  
  CountMap *mp = NULL;
  FILE *ff = NULL;
  if (validation) {
    mp = &_validation_map;
    ff = _vf;
  } else {
    mp = &_test_map;
    ff = _tf;
  }

  for (CountMap::const_iterator i = mp->begin();
       i != mp->end(); ++i) {
    const Rating &e = i->first;
    uint32_t n = e.first;
    uint32_t m = e.second;

    yval_t r = i->second;
    double u = rating_likelihood(n,m,r);
    s += u;
    k += 1;
  }

  double a = .0;
  info("s = %.5f\n", s);
  fprintf(ff, "%d\t%d\t%.9f\t%d\n", _iter, duration(), s / k, k);
  fflush(ff);
  a = s / k;  
  
  if (!validation)
    return;
  
  bool stop = false;
  int why = -1;
  if (_iter > 10) {
    if (a > _prev_h && _prev_h != 0 && fabs((a - _prev_h) / _prev_h) < 0.00001) {
      stop = true;
      why = 0;
    } else if (a < _prev_h)
      _nh++;
    else if (a > _prev_h)
      _nh = 0;

    if (_nh > 3) { // be robust to small fluctuations in predictive likelihood
      why = 1;
      stop = true;
    }
  }
  _prev_h = a;
  FILE *f = fopen(Env::file_str("/max.txt").c_str(), "w");
  fprintf(f, "%d\t%d\t%.5f\t%d\n", 
	  _iter, duration(), a, why);
  fclose(f);
  if (stop) {
    do_on_stop();
    exit(0);
  }
}

double
BurstyGAP::rating_likelihood(uint32_t p, uint32_t q, yval_t y) const
{
  const double **etheta = _theta.expected_v().const_data();
  GPMatrix *x = _beta[q];
  const double **ebeta = x->expected_v().const_data();
  
  double s = .0;
  for (uint32_t k = 0; k < _k; ++k)
    s += etheta[p][k] * ebeta[q][k];
  
  if (s < 1e-30)
    s = 1e-30;
  
  if (_env.binary_data)
    return y == 0 ? -s : log(1 - exp(-s));    
  return y * log(s) - s - log_factorial(y);
}

double
BurstyGAP::log_factorial(uint32_t n)  const
{ 
  double v = log(1);
  for (uint32_t i = 2; i <= n; ++i)
    v += log(i);
  return v;
} 

void
BurstyGAP::do_on_stop()
{
  gen_ranking_for_users(false);
}

void
BurstyGAP::compute_precision(bool save_ranking_file)
{
  double mhits10 = 0, mhits100 = 0;
  uint32_t total_users = 0;
  FILE *f = 0;
  if (save_ranking_file)
    f = fopen(Env::file_str("/ranking.tsv").c_str(), "w");
  
  if (!save_ranking_file) {
    _sampled_users.clear();
    do {
      uint32_t n = gsl_rng_uniform_int(_r, _n);
      _sampled_users[n] = true;
    } while (_sampled_users.size() < 1000 && _sampled_users.size() < _n / 2);
  }
  
  KVArray mlist(_m);
  for (UserMap::const_iterator itr = _sampled_users.begin();
       itr != _sampled_users.end(); ++itr) {
    uint32_t n = itr->first;
    
    for (uint32_t m = 0; m < _m; ++m) {
      if (_ratings.r(n,m) > 0) { // skip training
	mlist[m].first = m;
	mlist[m].second = .0;
	continue;
      }
      double u = prediction_score(n, m);
      mlist[m].first = m;
      mlist[m].second = u;
    }
    uint32_t hits10 = 0, hits100 = 0;
    mlist.sort_by_value();
    for (uint32_t j = 0; j < mlist.size() && j < _topN_by_user; ++j) {
      KV &kv = mlist[j];
      uint32_t m = kv.first;
      double pred = kv.second;
      Rating r(n, m);

      uint32_t m2 = 0, n2 = 0;
      if (save_ranking_file) {
	IDMap::const_iterator it = _ratings.seq2user().find(n);
	assert (it != _ratings.seq2user().end());
	
	IDMap::const_iterator mt = _ratings.seq2movie().find(m);
	if (mt == _ratings.seq2movie().end())
	  continue;
      
	m2 = mt->second;
	n2 = it->second;
      }

      CountMap::const_iterator itr = _test_map.find(r);
      if (itr != _test_map.end()) {
	int v = itr->second;
	v = _ratings.rating_class(v);
	assert(v > 0);
	if (save_ranking_file) {
	  if (_ratings.r(n, m) == .0) // skip training
	    fprintf(f, "%d\t%d\t%.5f\t%d\n", n2, m2, pred, v);
	}
	
	if (j < 10) {
	  hits10++;
	  hits100++;
	} else if (j < 100) {
	  hits100++;
	}
      } else {
	if (save_ranking_file) {
	  if (_ratings.r(n, m) == .0) // skip training
	    fprintf(f, "%d\t%d\t%.5f\t%d\n", n2, m2, pred, 0);
	}
      }
    }
    mhits10 += (double)hits10 / 10;
    mhits100 += (double)hits100 / 100;
    total_users++;
  }
  if (save_ranking_file)
    fclose(f);
  fprintf(_pf, "%d\t%.5f\t%.5f\n", 
	  total_users,
	  (double)mhits10 / total_users, 
	  (double)mhits100 / total_users);
  fflush(_pf);
}

double
BurstyGAP::prediction_score(uint32_t user, uint32_t movie) const
{
  const double **etheta = _theta.expected_v().const_data();
  GPMatrix *x = _beta[q];
  const double **ebeta = x->expected_v().const_data();
  double s = .0;
  for (uint32_t k = 0; k < _k; ++k)
    s += etheta[user][k] * ebeta[movie][k];
  
  if (_use_rate_as_score)
    return s;
  
  if (s < 1e-30)
    s = 1e-30;
  double prob_zero = exp(-s);
  return 1 - prob_zero;
}

void
BurstyGAP::gen_ranking_for_users(bool load)
{
  if (load)
    load_beta_and_theta();

  char buf[4096];
  sprintf(buf, "%s/test_users.tsv", _env.datfname.c_str());
  FILE *f = fopen(buf, "r");
  if (!f) { 
    lerr("cannot open %s", buf);
    return;
  }
  //assert(f);
  _sampled_users.clear();
  _ratings.read_test_users(f, &_sampled_users);
  fclose(f);
  compute_precision(true);
  printf("DONE writing ranking.tsv in output directory\n");
  fflush(stdout);
}


void
BurstyGAP::load_beta_and_theta()
{
  _beta.load();
  _theta.load();
  if (_env.bias) {
    _betabias.load();
    _thetabias.load();
  }
}

  

