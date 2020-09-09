{ stdenv, lib, buildPythonPackage, fetchPypi, python, pythonOlder
, pytestrunner, pyhamcrest
, six, isodate, tornado_5, aenum
}:

buildPythonPackage rec {
  pname = "gremlinpython";
  version = "3.4.8";

  src = fetchPypi {
    inherit pname version;
    sha256 = "10fn4a7y4ak8yf5hb3f7ala33h940yp1v86waf0bzlny124p4kws";
  };

  # nativeBuildInputs = [ cython ];
  # buildInputs = [ libev ];
  propagatedBuildInputs = [ pytestrunner six isodate tornado_5 aenum ];
  #   ++ lib.optionals (pythonOlder "3.4") [ futures ];

  checkInputs = [ pyhamcrest ];
  doCheck = false; # Only builds tests with PyHamcrest < 2, but nixpkgs version is >= 2

  meta = with lib; {
    description = "Apache TinkerPop™ is a graph computing framework for both graph databases (OLTP) and graph analytic systems (OLAP). Gremlin is the graph traversal language of TinkerPop.";
    homepage = "http://tinkerpop.apache.org/";
    license = licenses.asl20;
    maintainers = with maintainers; [ turion ];
  };
}
